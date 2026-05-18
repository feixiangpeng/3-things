"""Partial (fragment + session) eval harness for live extraction rounds."""
from __future__ import annotations

import argparse
import json
import pathlib
import sys
from dataclasses import dataclass

from live_replay import LiveStep, live_steps_for_case, should_skip_model_round
from scorer import score
from tool_runner import build_draft
from tool_session import SessionState, run_live_steps

REPO = pathlib.Path(__file__).resolve().parent.parent
FIXTURE_PATH = REPO / "ThreeThings" / "Fixtures" / "voice_extraction_cases.json"
TRACES_DIR = pathlib.Path(__file__).resolve().parent / "traces" / "diagnostic"


@dataclass
class StepView:
    index: int
    full: str
    fragment: str
    finished: bool
    skip: bool
    selected: list[str]
    extra: list[str]


def load_cases() -> dict[str, dict]:
    return {c["id"]: c for c in json.loads(FIXTURE_PATH.read_text())["cases"]}


def walk_steps(steps: list[LiveStep]) -> list[StepView]:
    """Simulate session advancement without calling a model."""
    session: dict | None = None
    views: list[StepView] = []
    from live_replay import advance_session_after_round

    for i, step in enumerate(steps):
        skip = should_skip_model_round(step)
        selected: list[str] = []
        extra: list[str] = []
        if session:
            selected = list(session.get("selectedTasks") or session.get("selected_tasks") or [])
            extra = list(session.get("extraCandidates") or session.get("extra_candidates") or [])
        views.append(
            StepView(
                index=i,
                full=step.full_transcript,
                fragment=step.new_fragment,
                finished=step.user_finished_speaking,
                skip=skip,
                selected=selected,
                extra=extra,
            )
        )
        session = advance_session_after_round(session, step, skipped=skip)
    return views


def walk_case(case_id: str, *, variant_index: int = 0) -> list[StepView]:
    cases = load_cases()
    case = cases[case_id]
    steps = live_steps_for_case(case, variant_index=variant_index)
    return walk_steps(steps)


def assert_partial_invariants(steps: list[LiveStep]) -> None:
    if not steps:
        raise AssertionError("expected at least one step")
    prev_len = 0
    for step in steps:
        full = step.full_transcript
        if len(full) < prev_len:
            raise AssertionError(f"full transcript shrank: {full!r}")
        prev_len = len(full)
        if not step.user_finished_speaking and not step.new_fragment.strip():
            if not should_skip_model_round(step):
                raise AssertionError("empty fragment on live step must be client-skip")


class ScriptedModelRound:
    """model_round(step, session) from trace steps[]."""

    def __init__(self, scripted_steps: list[dict]) -> None:
        self._steps = scripted_steps
        self._index = 0

    def __call__(self, step: LiveStep, session: SessionState | None) -> list[dict]:
        if self._index >= len(self._steps):
            return [{"tool": "no_action", "reason": "unchanged"}]
        raw = self._steps[self._index]
        self._index += 1
        expected_full = str(raw.get("full", ""))
        if expected_full and expected_full != step.full_transcript:
            raise AssertionError(
                f"trace step {self._index} full mismatch: {expected_full!r} vs {step.full_transcript!r}"
            )
        return list(raw.get("calls") or [])


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


def run_offline_case(case: dict, trace_path: pathlib.Path) -> tuple[SessionState | None, list[dict], object]:
    data = json.loads(trace_path.read_text())
    steps_raw = data.get("steps")
    if not steps_raw:
        raise ValueError(f"trace {trace_path} must have steps[] for partial harness")
    fixture_steps = live_steps_for_case(case)
    scripted = ScriptedModelRound(steps_raw)
    session, trace = run_live_steps(fixture_steps, initial=None, model_round=scripted)
    final_transcript = fixture_steps[-1].full_transcript if fixture_steps else ""
    draft, err = _session_final_draft(session, final_transcript)
    return session, trace, (draft, err)


def print_walk_table(views: list[StepView]) -> None:
    for v in views:
        kind = "skip" if v.skip else "model"
        tasks = " | ".join(v.selected) if v.selected else "(none)"
        print(f"--- round {v.index} [{kind}] finished={v.finished}")
        print(f"  full:     {v.full}")
        print(f"  fragment: {v.fragment or '(empty)'}")
        print(f"  selected: {tasks}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Partial harness utilities")
    sub = ap.add_subparsers(dest="cmd", required=True)
    walk_p = sub.add_parser("walk", help="Print full/fragment per round for a case")
    walk_p.add_argument("--case", required=True)
    walk_p.add_argument("--variant", type=int, default=0)
    args = ap.parse_args()

    if args.cmd == "walk":
        views = walk_case(args.case, variant_index=args.variant)
        print_walk_table(views)
        assert_partial_invariants(
            live_steps_for_case(load_cases()[args.case], variant_index=args.variant)
        )
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
