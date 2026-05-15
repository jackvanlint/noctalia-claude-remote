#!/usr/bin/env python3
"""
Fetches Claude Code rate-limit usage from the Anthropic OAuth API and
supplements it with local JSONL stats. Outputs a single JSON object.

Keys:
  pct_5h          float 0–1  (session 5-hour utilisation)
  pct_7d          float 0–1  (weekly 7-day utilisation)
  reset_5h_mins   int        minutes until 5-hour window resets
  reset_7d_mins   int        minutes until 7-day window resets
  tokens_today    int        input+output tokens from today's assistant messages
  prompts_5h      int        user messages in last 5 hours
  prompts_7d      int        user messages in last 7 days
  api_ok          bool       True if rate-limit data came from the API
  days            list       last 7 days [{date, tokens, prompts}] oldest first
"""
import json, os, sys
from datetime import datetime, timezone, timedelta
from urllib.request import Request, urlopen
from urllib.error import URLError

# ── helpers ──────────────────────────────────────────────────────────────────

def parse_ts(s):
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None

def normalize_util(v):
    try:
        n = float(v)
    except Exception:
        return -1.0
    if n < 0:
        return -1.0
    return min(1.0, n / 100.0)

def mins_until(ts_str):
    ts = parse_ts(ts_str)
    if ts is None:
        return 0
    diff = (ts - datetime.now(timezone.utc)).total_seconds()
    return max(0, int(diff / 60))

def iter_recent_jsonl(root, cutoff):
    """Yield recent Claude transcript files without repeatedly reading history."""
    if not os.path.isdir(root):
        return
    files = []
    for dirpath, _, filenames in os.walk(root):
        for fname in filenames:
            if not fname.endswith(".jsonl"):
                continue
            path = os.path.join(dirpath, fname)
            try:
                if os.path.islink(path):
                    continue
                mtime = datetime.fromtimestamp(os.path.getmtime(path), tz=timezone.utc)
            except OSError:
                continue
            if mtime >= cutoff:
                files.append((mtime, path))
    files.sort(reverse=True)
    for _, path in files:
        yield path

# ── OAuth token ───────────────────────────────────────────────────────────────

creds_path = os.path.expanduser("~/.claude/.credentials.json")
access_token = None
plan_type = ""
plan_tier = ""
try:
    with open(creds_path) as f:
        creds = json.load(f)
    # Claude Code stores tokens under various keys depending on version
    for key in ("claudeAiOauth", "oauth", ""):
        obj = creds.get(key, creds) if key else creds
        access_token = obj.get("access_token") or obj.get("accessToken")
        if access_token:
            break
    oauth_obj = creds.get("claudeAiOauth", creds)
    plan_type = oauth_obj.get("subscriptionType", "") or ""
    plan_tier = oauth_obj.get("rateLimitTier", "") or ""
except Exception:
    pass

# ── Rate-limit API call ───────────────────────────────────────────────────────

pct_5h = -1.0
pct_7d = -1.0
reset_5h_mins = 0
reset_7d_mins = 0
api_ok = False

if access_token:
    try:
        req = Request(
            "https://api.anthropic.com/api/oauth/usage",
            headers={
                "Authorization": "Bearer " + access_token,
                "anthropic-beta": "oauth-2025-04-20",
            },
        )
        with urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read())

        # Response is a flat dict: {"five_hour": {utilization, resets_at}, "seven_day": {...}, ...}
        fh = data.get("five_hour") or {}
        sd = data.get("seven_day") or {}

        pct_5h = normalize_util(fh.get("utilization", -1))
        pct_7d = normalize_util(sd.get("utilization", -1))
        if fh.get("resets_at"):
            reset_5h_mins = mins_until(fh["resets_at"])
        if sd.get("resets_at"):
            reset_7d_mins = mins_until(sd["resets_at"])

        api_ok = pct_5h >= 0 or pct_7d >= 0
    except Exception:
        pass

# ── Local JSONL stats ─────────────────────────────────────────────────────────

now         = datetime.now(timezone.utc)
today       = now.strftime("%Y-%m-%d")
five_h_ago  = now - timedelta(hours=5)
seven_d_ago = now - timedelta(days=7)
proj        = os.path.expanduser("~/.claude/projects")

days_list = [(now - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)]
day_tokens  = {d: 0 for d in days_list}
day_prompts = {d: 0 for d in days_list}

prompts_5h   = 0
prompts_7d   = 0
tokens_today = 0
oldest_5h    = None
oldest_7d    = None

for path in iter_recent_jsonl(proj, seven_d_ago - timedelta(days=1)):
    try:
        with open(path) as f:
            for line in f:
                try:
                    obj = json.loads(line)
                    ts  = parse_ts(obj.get("timestamp", ""))
                    if ts is None or ts < seven_d_ago:
                        continue
                    day = ts.strftime("%Y-%m-%d")

                    if obj.get("type") == "user":
                        if ts >= five_h_ago:
                            prompts_5h += 1
                            if oldest_5h is None or ts < oldest_5h:
                                oldest_5h = ts
                        prompts_7d += 1
                        if oldest_7d is None or ts < oldest_7d:
                            oldest_7d = ts
                        if day in day_prompts:
                            day_prompts[day] += 1

                    elif obj.get("type") == "assistant":
                        usage = obj.get("message", {}).get("usage", {})
                        t = usage.get("input_tokens", 0) + usage.get("output_tokens", 0)
                        if day == today:
                            tokens_today += t
                        if day in day_tokens:
                            day_tokens[day] += t
                except Exception:
                    pass
    except Exception:
        pass

# Fallback reset times from local counts
if not api_ok:
    if oldest_5h:
        reset_5h_mins = max(0, int((oldest_5h + timedelta(hours=5) - now).total_seconds() / 60))
    if oldest_7d:
        reset_7d_mins = max(0, int((oldest_7d + timedelta(days=7)  - now).total_seconds() / 60))

days_out = [{"date": d, "tokens": day_tokens[d], "prompts": day_prompts[d]} for d in days_list]

print(json.dumps({
    "pct_5h":        round(pct_5h, 4),
    "pct_7d":        round(pct_7d, 4),
    "reset_5h_mins": reset_5h_mins,
    "reset_7d_mins": reset_7d_mins,
    "tokens_today":  tokens_today,
    "prompts_5h":    prompts_5h,
    "prompts_7d":    prompts_7d,
    "api_ok":        api_ok,
    "days":          days_out,
    "plan_type":     plan_type,
    "plan_tier":     plan_tier,
}))
