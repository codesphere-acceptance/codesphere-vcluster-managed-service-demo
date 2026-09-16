#!/usr/bin/env bash
# Verify the dev toolchain and (optionally) Codesphere API access.
# Run via `mise run doctor`.
set -euo pipefail

ok=0
warn=0
fail=0
say()  { printf '  %s\n' "$*"; }
good() { printf '  \033[32mok\033[0m   %s\n' "$*"; ok=$((ok + 1)); }
note() { printf '  \033[33mwarn\033[0m %s\n' "$*"; warn=$((warn + 1)); }
bad()  { printf '  \033[31mmiss\033[0m %s\n' "$*"; fail=$((fail + 1)); }

echo "== deploy toolchain =="
for cmd in helm kubectl jq yq gh direnv; do
	if command -v "$cmd" >/dev/null 2>&1; then
		good "$cmd ($("$cmd" version --short 2>/dev/null || "$cmd" --version 2>/dev/null | head -1))"
	else
		bad "$cmd not found — run 'mise install'"
	fi
done

echo ""
echo "== Codesphere CLI =="
if command -v cs >/dev/null 2>&1; then
	good "cs ($(command -v cs))"
else
	note "cs not found — install the Codesphere CLI to create/list workspaces (https://docs.codesphere.com)"
fi

echo ""
echo "== Codesphere API access =="
if [[ -z "${CS_TOKEN:-}" ]]; then
	note "CS_TOKEN not set — cp .env.example .env.local, add a token, then 'direnv allow' (API tools stay offline until then)"
elif [[ -z "${CS_API:-}" ]]; then
	note "CS_API not set — see .env.example"
else
	code=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${CS_TOKEN}" "${CS_API}/teams" 2>/dev/null || echo "000")
	if [[ "$code" == "200" ]]; then
		good "reached ${CS_API} and token accepted"
	else
		bad "API check failed (HTTP ${code}) against ${CS_API}/teams — check CS_API / CS_TOKEN"
	fi
fi

echo ""
printf 'summary: %d ok, %d warn, %d missing\n' "$ok" "$warn" "$fail"
[[ "$fail" -eq 0 ]] || exit 1
