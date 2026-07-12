#!/bin/bash
set -uo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
VALID='^(Media|Productivity|Home|Networking|AI|Finance|Social|Developer|Others)$'
rc=0
for f in "$ROOT"/Apps/*/docker-compose.yml; do
  [[ -f "$f" ]] || continue
  app=$(basename "$(dirname "$f")")
  if grep -q 'en_us:' "$f"; then echo "[$app] lowercase en_us locale key"; rc=1; fi
  id=$(yq eval '.x-casaos.id // ""' "$f")
  if [[ "$id" != com.bigbeartechworld.* ]]; then echo "[$app] missing/invalid x-casaos.id ('$id')"; rc=1; fi
  cat=$(yq eval '.x-casaos.category // ""' "$f")
  if ! echo "$cat" | grep -Eq "$VALID"; then echo "[$app] invalid category ('$cat')"; rc=1; fi
done
[[ $rc -eq 0 ]] && echo "lint-casaos-v2: all apps v2-clean"
exit $rc
