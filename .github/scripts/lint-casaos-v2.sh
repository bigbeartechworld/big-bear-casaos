#!/bin/bash
set -uo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
VALID='^(Media|Productivity|Home|Networking|AI|Finance|Social|Developer|Others)$'
rc=0
checked=0
for f in "$ROOT"/Apps/*/docker-compose.yml; do
  [[ -f "$f" ]] || continue
  app=$(basename "$(dirname "$f")")
  if ! yq eval '.' "$f" >/dev/null 2>&1; then echo "[$app] malformed YAML"; rc=1; continue; fi
  id=$(yq eval '.x-casaos.id // ""' "$f")
  [[ -z "$id" ]] && continue
  checked=$((checked+1))
  if [[ "$id" != com.bigbeartechworld.* ]]; then echo "[$app] invalid x-casaos.id ('$id')"; rc=1; fi
  if yq eval '[.. | select(tag == "!!map") | keys | .[]] | any_c(. == "en_us")' "$f" 2>/dev/null | grep -q true; then
    echo "[$app] lowercase en_us locale key"; rc=1
  fi
  cat=$(yq eval '.x-casaos.category // ""' "$f")
  if ! echo "$cat" | grep -Eq "$VALID"; then echo "[$app] invalid category ('$cat')"; rc=1; fi
done
[[ $rc -eq 0 ]] && echo "lint-casaos-v2: $checked migrated app(s) v2-clean"
exit $rc
