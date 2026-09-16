#!/usr/bin/env bash
# Inspect the Codesphere managed-service provider catalog over the Public API.
#
#   tools/providers.sh                 # list every provider (name + version)
#   tools/providers.sh virtual-k8s     # show one provider's plans + parameter
#                                      # bounds, and a ready-to-paste ci.yml plan
#
# Reads CS_API + CS_TOKEN from the environment (direnv loads .env.local). This is
# how the vCluster plan values in ci.yml were resolved — re-run it to refresh
# them for your instance.
set -euo pipefail

PROVIDER="${1:-}"

fail() { echo "error: $*" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v jq   >/dev/null 2>&1 || fail "jq is required (mise install)"
[[ -n "${CS_API:-}" ]]   || fail "CS_API not set — cp .env.example .env.local and 'direnv allow'"
[[ -n "${CS_TOKEN:-}" ]] || fail "CS_TOKEN not set — add it to .env.local"

catalog="$(curl -sS -f -H "Authorization: Bearer ${CS_TOKEN}" "${CS_API}/managed-services/providers")" \
	|| fail "could not reach ${CS_API}/managed-services/providers"

# Normalize to an array regardless of how the API wraps the payload.
providers="$(jq 'if type=="array" then . else (.providers // .items // .data // []) end' <<<"$catalog")"

if [[ -z "$PROVIDER" ]]; then
	echo "Providers on ${CS_API}:"
	jq -r '.[] | "  \(.name)  \(.version // .schemaVersion // "")"' <<<"$providers" | sort -u
	echo ""
	echo "Run 'tools/providers.sh <name>' for a provider's plans and parameters."
	exit 0
fi

obj="$(jq --arg n "$PROVIDER" '.[] | select(.name==$n)' <<<"$providers")"
[[ -n "$obj" ]] || fail "provider '$PROVIDER' not found in the catalog"

echo "== ${PROVIDER} ($(jq -r '.displayName // .name' <<<"$obj"), schemaVersion $(jq -r '.schemaVersion // .version' <<<"$obj")) =="
echo ""
echo "Plans:"
jq -r '.plans[]? | "  id \(.id)  \(.name // "")  \(.description // "")"' <<<"$obj"
echo ""
echo "Parameter bounds:"
jq -r '.resourceParameters // {} | to_entries[] | "  \(.key): min \(.value.schema.minimum // "-") max \(.value.schema.maximum // "-")  (\(.value.schema.description // ""))"' <<<"$obj"

# Emit a ci.yml plan block seeded with the plan's default parameters — a
# known-valid starting point to paste under a managed-service definition.
echo ""
echo "Suggested ci.yml plan (plan defaults):"
jq -r '
	(.plans[0].id // 0) as $pid |
	"    plan:\n      id: \($pid)\n      parameters:" ,
	(.plans[0].parameters // {} | to_entries[] | "        \(.key): \(.value)")
' <<<"$obj"
