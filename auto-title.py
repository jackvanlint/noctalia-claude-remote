#!/usr/bin/env python3
"""
Stop hook: auto-title new remote sessions from their first user message.
Only runs when CLAUDE_REMOTE_SESSION=1 is set in the environment.

Auth resolution order:
  1. OAuth access token from ~/.claude/.credentials.json (the same login
     Claude Code itself uses — counts against your subscription quota)
  2. ANTHROPIC_API_KEY env var (billed separately as API usage)
"""
import json
import os
import pathlib
import sys
import urllib.request


def extract_text(content) -> str:
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(block.get("text", ""))
        return " ".join(parts).strip()
    return ""


def get_auth():
    """Returns (auth_type, value): ('oauth', token) | ('api_key', key) | (None, None)."""
    creds_path = pathlib.Path.home() / ".claude" / ".credentials.json"
    if creds_path.exists():
        try:
            with open(creds_path) as f:
                creds = json.load(f)
            for key in ("claudeAiOauth", "oauth", ""):
                obj = creds.get(key, creds) if key else creds
                if isinstance(obj, dict):
                    token = obj.get("access_token") or obj.get("accessToken")
                    if token:
                        return ("oauth", token)
        except Exception:
            pass

    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if api_key:
        return ("api_key", api_key)

    return (None, None)


def build_headers(auth_type, auth_value):
    if auth_type == "oauth":
        return {
            "Authorization": "Bearer " + auth_value,
            "anthropic-version": "2023-06-01",
            "anthropic-beta": "oauth-2025-04-20",
            "content-type": "application/json",
        }
    return {
        "x-api-key": auth_value,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }


def main():
    if not os.environ.get("CLAUDE_REMOTE_SESSION"):
        sys.exit(0)

    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    session_id = data.get("session_id", "")
    transcript_path = data.get("transcript_path", "")

    if not session_id or not transcript_path:
        sys.exit(0)

    allowed_prefix = pathlib.Path.home() / ".claude"
    if not pathlib.Path(transcript_path).resolve().is_relative_to(allowed_prefix):
        sys.exit(0)

    if not os.path.exists(transcript_path):
        sys.exit(0)

    entries = []
    with open(transcript_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                pass

    # Skip if already titled
    if any(e.get("type") == "ai-title" for e in entries):
        sys.exit(0)

    # Collect real human messages (not tool results)
    human_texts = []
    for entry in entries:
        if entry.get("type") != "user":
            continue
        msg = entry.get("message", {})
        if msg.get("role") != "user":
            continue
        content = msg.get("content", "")
        # Skip pure tool-result content
        if isinstance(content, list):
            if all(isinstance(b, dict) and b.get("type") == "tool_result" for b in content if isinstance(b, dict)):
                continue
        text = extract_text(content)
        if text:
            human_texts.append(text)

    # Only rename on first exchange
    if len(human_texts) != 1:
        sys.exit(0)

    first_msg = human_texts[0][:500]

    auth_type, auth_value = get_auth()
    if not auth_type:
        sys.exit(0)

    payload = json.dumps({
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 15,
        "messages": [{
            "role": "user",
            "content": (
                "Reply with ONLY a 3-5 word title-case phrase (no punctuation) "
                f"summarising this message: {first_msg}"
            )
        }]
    }).encode()

    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=payload,
        headers=build_headers(auth_type, auth_value),
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
        title_words = result["content"][0]["text"].strip().rstrip(".")
    except Exception:
        sys.exit(0)

    if not title_words:
        sys.exit(0)

    full_title = f"Remote Session: {title_words}"

    entry = json.dumps({
        "type": "ai-title",
        "aiTitle": full_title,
        "sessionId": session_id,
    })

    with open(transcript_path, "a") as f:
        f.write(entry + "\n")


if __name__ == "__main__":
    main()
