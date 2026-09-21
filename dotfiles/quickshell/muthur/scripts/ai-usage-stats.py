#!/usr/bin/env python3
"""Aggregate an AI CLI's local token records over the last 7 days.

Usage: ai-usage-stats.py claude|codex
Prints JSON: {"days": [{"label": "Mon", "tokens": N}, ... 7 entries, oldest
first, last one "Today"], "models": [{"name": "Sonnet 5", "tokens": N}, ...]}

Reads only files modified within the window, so a machine with months of
sessions still answers quickly. Token totals include cached/cache-write
input, matching what the CLIs count against their limits.
"""
import glob
import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

DAYS = 7


def pretty_model(model):
    name = re.sub(r"^claude-", "", model)
    name = re.sub(r"-\d{8}$", "", name)
    parts = name.split("-")
    out = []
    for p in parts:
        if out and re.fullmatch(r"\d+", p) and re.fullmatch(r".*\d", out[-1]):
            out[-1] += "." + p
        else:
            out.append(p.upper() if p.lower().startswith("gpt") else p.capitalize())
    return " ".join(out)


def recent_files(pattern, since):
    for path in glob.glob(pattern, recursive=True):
        try:
            if os.path.getmtime(path) >= since.timestamp():
                yield path
        except OSError:
            pass


def parse_ts(value):
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone()
    except (ValueError, AttributeError):
        return None


def claude_records(since):
    home = os.path.expanduser("~/.claude/projects")
    for path in recent_files(os.path.join(home, "**", "*.jsonl"), since):
        with open(path, errors="replace") as fh:
            for line in fh:
                if '"usage"' not in line:
                    continue
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                message = entry.get("message") or {}
                usage = message.get("usage")
                if not isinstance(usage, dict):
                    continue
                ts = parse_ts(entry.get("timestamp", ""))
                if ts is None:
                    continue
                tokens = sum(usage.get(k, 0) or 0 for k in (
                    "input_tokens", "output_tokens",
                    "cache_creation_input_tokens", "cache_read_input_tokens"))
                yield ts, message.get("model") or "unknown", tokens


def codex_records(since):
    home = os.path.expanduser("~/.codex/sessions")
    for path in recent_files(os.path.join(home, "**", "*.jsonl"), since):
        model = "unknown"
        with open(path, errors="replace") as fh:
            for line in fh:
                if '"model"' not in line and "token_usage_record" not in line:
                    continue
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                payload = entry.get("payload") or {}
                if isinstance(payload, dict) and isinstance(payload.get("model"), str):
                    model = payload["model"]
                if entry.get("type") != "token_usage_record":
                    continue
                usage = payload.get("usage") or {}
                ts = parse_ts(entry.get("timestamp", ""))
                if ts is None:
                    continue
                tokens = usage.get("total_tokens")
                if tokens is None:
                    tokens = (usage.get("input_tokens", 0) or 0) + (usage.get("output_tokens", 0) or 0)
                yield ts, model, tokens


def main():
    agent = sys.argv[1] if len(sys.argv) > 1 else ""
    source = {"claude": claude_records, "codex": codex_records}.get(agent)
    if source is None:
        print(json.dumps({"error": "unknown agent"}))
        return 1

    today = datetime.now().astimezone().replace(hour=0, minute=0, second=0, microsecond=0)
    since = today - timedelta(days=DAYS - 1)
    by_day = defaultdict(int)
    by_model = defaultdict(int)
    for ts, model, tokens in source(since):
        day = ts.replace(hour=0, minute=0, second=0, microsecond=0)
        if day < since:
            continue
        by_day[day.date()] += tokens
        by_model[model] += tokens

    days = []
    for i in range(DAYS):
        day = (since + timedelta(days=i)).date()
        label = "Today" if i == DAYS - 1 else day.strftime("%a")
        days.append({"label": label, "tokens": by_day.get(day, 0)})
    models = [{"name": pretty_model(m), "tokens": t}
              for m, t in sorted(by_model.items(), key=lambda kv: -kv[1])
              if t > 0 and not m.startswith("<")]
    print(json.dumps({"days": days, "models": models}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
