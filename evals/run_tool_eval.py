"""Multi-step Groq tool-calling eval using liveSnapshots replay."""
from __future__ import annotations

import argparse
import json
import pathlib
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone

from live_replay import LiveStep, live_steps_for_case
from runner import DIAGNOSTIC_SUBSET, EXPANDED_SUBSET, FIXTURE, RunOutcome, _outcome
from scorer import score
from step_scorer import expectations_for_case, score_step
from tool_extractor import GroqToolExtractor, ToolExtractorConfig
from tool_runner import build_draft
from tool_session import SessionState, run_live_steps_with_results

REPO = pathlib.Path(__file__).resolve().parent


@dataclass
class StepResultReport:
    index: int
    passed: bool
    full: str
    fragment: str
    finished: bool
    skipped: bool
    selected_tasks: list[str]
    extra_candidates: list[str]
    calls: list[dict]
    reasons: list[str]
    tool_warnings: list[str] = field(default_factory=list)


@dataclass
class ToolVariantReport:
    case_id: str
    category: str
    variant_index: int
    replay_mode: str
    steps: int
    tool_rounds: int
    runs: list[RunOutcome]
    pass_rate: float
    first_pass: bool
    trace: list[dict] | None = None
    step_results: list[StepResultReport] | None = None
    all_steps_passed: bool | None = None
    final_passed: bool | None = None


def _session_final_draft(session: SessionState | None, transcript: str):
    if session is None or (not session.selected_tasks and not session.extra_candidates):
        return None, "empty_model_output"
    try:
        draft = build_draft(
            session.selected_tasks,
            session.extra_candidates,
            len(session.selected_tasks) + len(session.extra_candidates) > 3,
            contains_actionable_tasks=True,
            cleaned_transcript=transcript,
        )
        return draft, None
    except ValueError:
        return None, "empty_model_output"


def _score_steps_for_case(
    case: dict,
    live_results: list,
    *,
    strict_tools: bool,
) -> list[StepResultReport]:
    step_exps = expectations_for_case(case)
    reports: list[StepResultReport] = []
    for i, (lr, step_exp) in enumerate(zip(live_results, step_exps)):
        sess = lr.session
        selected = list(sess.selected_tasks) if sess else []
        extras = list(sess.extra_candidates) if sess else []
        step_score = score_step(
            step_exp,
            selected=selected,
            extras=extras,
            calls=lr.calls,
            strict_tools=strict_tools,
        )
        reports.append(
            StepResultReport(
                index=i,
                passed=step_score.passed,
                full=lr.step.full_transcript,
                fragment=lr.step.new_fragment,
                finished=lr.step.user_finished_speaking,
                skipped=lr.skipped,
                selected_tasks=selected,
                extra_candidates=extras,
                calls=lr.calls,
                reasons=step_score.reasons,
                tool_warnings=step_score.tool_warnings,
            )
        )
    return reports


def run_one_case(
    case: dict,
    *,
    variant_index: int,
    extractor: GroqToolExtractor,
    capture_trace: bool,
    score_steps: bool,
    strict_tools: bool,
) -> ToolVariantReport:
    steps = live_steps_for_case(case, variant_index=variant_index)
    replay_mode = "fixture_snapshots" if case.get("liveSnapshots") else "synthetic"

    def model_round(step: LiveStep, sess: SessionState | None) -> list[dict]:
        return extractor.apply_round(step, sess)

    session, live_results = run_live_steps_with_results(
        steps, initial=None, model_round=model_round
    )

    trace = None
    if capture_trace:
        trace = [
            {
                "full": r.step.full_transcript,
                "fragment": r.step.new_fragment,
                "finished": r.step.user_finished_speaking,
                "calls": r.calls,
            }
            for r in live_results
        ]

    step_results: list[StepResultReport] | None = None
    all_steps_passed: bool | None = None
    if score_steps:
        step_results = _score_steps_for_case(case, live_results, strict_tools=strict_tools)
        all_steps_passed = all(s.passed for s in step_results) if step_results else True

    final_transcript = steps[-1].full_transcript if steps else ""
    draft, err = _session_final_draft(session, final_transcript)
    attempt = score(case, draft, err)
    outcome = _outcome(draft, err, attempt)
    final_passed = outcome.passed

    first_pass = final_passed
    if score_steps and all_steps_passed is not None:
        first_pass = final_passed and all_steps_passed

    return ToolVariantReport(
        case_id=case["id"],
        category=case["category"],
        variant_index=variant_index,
        replay_mode=replay_mode,
        steps=len(steps),
        tool_rounds=sum(1 for r in live_results if not r.skipped),
        runs=[outcome],
        pass_rate=1.0 if first_pass else 0.0,
        first_pass=first_pass,
        trace=trace,
        step_results=step_results,
        all_steps_passed=all_steps_passed,
        final_passed=final_passed,
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--subset", choices=["diagnostic", "expanded", "full"], default="diagnostic")
    ap.add_argument("--cases", nargs="*", default=None)
    ap.add_argument("--variants", type=int, default=1)
    ap.add_argument("--out", type=pathlib.Path, default=REPO / "reports" / "tools_diagnostic.json")
    ap.add_argument("--model", default="llama-3.1-8b-instant")
    ap.add_argument("--capture-trace", action="store_true")
    ap.add_argument(
        "--score-steps",
        action="store_true",
        help="Score each live step against liveStepExpectations",
    )
    ap.add_argument(
        "--strict-tools",
        action="store_true",
        help="Fail steps when tool_warnings are present (default: advisory only)",
    )
    args = ap.parse_args()

    data = json.loads(FIXTURE.read_text())
    cases = data["cases"]
    if args.subset == "diagnostic":
        ids = set(DIAGNOSTIC_SUBSET)
        cases = [c for c in cases if c["id"] in ids]
    elif args.subset == "expanded":
        ids = set(EXPANDED_SUBSET)
        cases = [c for c in cases if c["id"] in ids]
    if args.cases:
        want = set(args.cases)
        cases = [c for c in cases if c["id"] in want]

    extractor = GroqToolExtractor(ToolExtractorConfig(model=args.model))
    reports: list[ToolVariantReport] = []
    for case in cases:
        for vi in range(min(args.variants, len(case["transcriptVariants"]))):
            print(f"Running {case['id']} variant {vi}...", flush=True)
            try:
                reports.append(
                    run_one_case(
                        case,
                        variant_index=vi,
                        extractor=extractor,
                        capture_trace=args.capture_trace or args.score_steps,
                        score_steps=args.score_steps,
                        strict_tools=args.strict_tools,
                    )
                )
            except Exception as e:  # noqa: BLE001
                attempt = score(case, None, f"runner_error:{type(e).__name__}:{e}")
                reports.append(
                    ToolVariantReport(
                        case_id=case["id"],
                        category=case["category"],
                        variant_index=vi,
                        replay_mode="error",
                        steps=0,
                        tool_rounds=0,
                        runs=[_outcome(None, str(e), attempt)],
                        pass_rate=0.0,
                        first_pass=False,
                        step_results=None,
                        all_steps_passed=False if args.score_steps else None,
                        final_passed=False,
                    )
                )
            time.sleep(0.5)

    passed = sum(1 for r in reports if r.first_pass)
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "model": args.model,
        "subset": args.subset,
        "score_steps": args.score_steps,
        "replay_mode": "fixture_snapshots",
        "total_variants": len(reports),
        "mean_pass_rate": round(passed / len(reports), 3) if reports else 0.0,
        "variants": [asdict(r) for r in reports],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, indent=2))
    print(json.dumps({"out": str(args.out), "passed": passed, "total": len(reports)}, indent=2))
    return 0 if passed == len(reports) else 1


if __name__ == "__main__":
    raise SystemExit(main())
