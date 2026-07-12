#!/bin/bash
set -uo pipefail
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
migrated=false
for f in "$ROOT"/Apps/*/docker-compose.yml; do
  [[ -f "$f" ]] || continue
  id=$(yq eval '.x-casaos.id // ""' "$f")
  if [[ "$id" == com.bigbeartechworld.* ]]; then migrated=true; break; fi
done
echo "migrated=$migrated"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "migrated=$migrated" >> "$GITHUB_OUTPUT"; fi
