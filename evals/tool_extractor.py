"""Groq tool-calling extractor for one live extraction round."""
from __future__ import annotations

import json
import re
from dataclasses import dataclass

from extractor import DEFAULT_MODEL, _load_client
from live_replay import LiveStep
from tool_schemas import TOOL_INSTRUCTIONS, groq_tools
from tool_session import SessionState


@dataclass
class ToolExtractorConfig:
    model: str = DEFAULT_MODEL
    temperature: float = 0.2
    max_output_tokens: int = 512


class GroqToolExtractor:
    def __init__(self, config: ToolExtractorConfig | None = None):
        self.config = config or ToolExtractorConfig()
        self.client = _load_client()

    def apply_round(self, step: LiveStep, session: SessionState | None) -> list[dict]:
        selected = ", ".join(session.selected_tasks) if session and session.selected_tasks else "(none)"
        extras = ", ".join(session.extra_candidates) if session and session.extra_candidates else "(none)"
        fragment = step.new_fragment or "(empty)"
        user_msg = (
            f"Full transcript:\n{step.full_transcript}\n"
            f"New fragment (since last applied position):\n{fragment}\n"
            f"User finished speaking: {'yes' if step.user_finished_speaking else 'no'}\n"
            f"Current selected (order preserved): {selected}\n"
            f"Current extras (overflow): {extras}\n"
            "Apply tools so the draft matches the transcript. If there are still no actionable tasks, call no_action."
        )
        resp = self.client.chat.completions.create(
            model=self.config.model,
            messages=[
                {"role": "system", "content": TOOL_INSTRUCTIONS},
                {"role": "user", "content": user_msg},
            ],
            tools=groq_tools(),
            tool_choice="required",
            temperature=self.config.temperature,
            max_tokens=self.config.max_output_tokens,
        )
        message = resp.choices[0].message
        return _parse_tool_calls(message.tool_calls or [])


def _parse_tool_calls(tool_calls: list) -> list[dict]:
    out: list[dict] = []
    for tc in tool_calls:
        name = tc.function.name
        try:
            args = json.loads(tc.function.arguments or "{}")
        except json.JSONDecodeError:
            args = {}
        if name == "add_task":
            out.append({"tool": "add_task", "text": str(args.get("text", ""))})
        elif name == "revise_task":
            out.append(
                {
                    "tool": "revise_task",
                    "pool": str(args.get("pool", "selected")),
                    "slot": int(args.get("slot", 0)),
                    "new_text": str(args.get("new_text", "")),
                }
            )
        elif name == "delete_task":
            out.append(
                {
                    "tool": "delete_task",
                    "pool": str(args.get("pool", "selected")),
                    "slot": int(args.get("slot", 0)),
                }
            )
        elif name == "clear_draft":
            out.append({"tool": "clear_draft"})
        elif name == "no_action":
            reason = str(args.get("reason", "incomplete"))
            if reason not in ("incomplete", "no_actionable", "unchanged"):
                reason = "incomplete"
            out.append({"tool": "no_action", "reason": reason})
    return out
