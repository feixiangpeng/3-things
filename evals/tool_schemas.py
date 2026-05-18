"""OpenAI-compatible tool definitions matching Swift ToolVoiceDraftExtractor."""
from __future__ import annotations

TOOL_INSTRUCTIONS = """You extract 1–3 focus tasks for TODAY from English voice text. Use ONLY the tools—never output JSON or lists in prose.
Rules: delete cancelled items (never mind, scratch that, actually no, wait no); merge duplicate phrasings; drop future-day-only items (tomorrow, next week, not today); keep negative commitments (don't X, avoid X); collapse substeps under one parent task; never invent tasks not grounded in the transcript.
If the new fragment is too short to interpret, or is filler/mic test with no actionable tasks, call no_action with reason incomplete or no_actionable.
If nothing should change, call no_action with reason unchanged.
Otherwise add, revise, or delete tasks to match the user's latest intent. Prefer revising over adding when correcting wording."""


def groq_tools() -> list[dict]:
    return [
        {
            "type": "function",
            "function": {
                "name": "add_task",
                "description": "Append one actionable task for today.",
                "parameters": {
                    "type": "object",
                    "properties": {"text": {"type": "string"}},
                    "required": ["text"],
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "revise_task",
                "description": "Replace text of a selected or extra task by index.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "pool": {"type": "string", "enum": ["selected", "extra"]},
                        "slot": {"type": "integer"},
                        "new_text": {"type": "string"},
                    },
                    "required": ["pool", "slot", "new_text"],
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "delete_task",
                "description": "Remove a task by pool and index.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "pool": {"type": "string", "enum": ["selected", "extra"]},
                        "slot": {"type": "integer"},
                    },
                    "required": ["pool", "slot"],
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "clear_draft",
                "description": "Remove all tasks when the user starts over.",
                "parameters": {"type": "object", "properties": {}},
            },
        },
        {
            "type": "function",
            "function": {
                "name": "no_action",
                "description": "Fragment incomplete, non-actionable, or no change needed.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "reason": {
                            "type": "string",
                            "enum": ["incomplete", "no_actionable", "unchanged"],
                        }
                    },
                    "required": ["reason"],
                },
            },
        },
    ]
