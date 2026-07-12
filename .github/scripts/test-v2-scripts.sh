#!/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="$SCRIPT_DIR/lint-casaos-v2.sh"
DETECT="$SCRIPT_DIR/detect-v2-migration.sh"

fail=0
pass() { echo "ok: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

mkapp() { # $1=root $2=name $3=compose-content
  mkdir -p "$1/Apps/$2"
  printf '%s' "$3" > "$1/Apps/$2/docker-compose.yml"
}

V2_CLEAN='name: c
services:
  a:
    image: x
x-casaos:
  id: com.bigbeartechworld.c
  category: Media
  title:
    en_US: C
'
V1_APP='name: v1
services:
  a:
    image: x
x-casaos:
  category: BigBearCasaOS
  title:
    en_us: V1
'
V2_BAD_ID='name: b
services:
  a:
    image: x
x-casaos:
  id: wrong.prefix.b
  category: Media
  title:
    en_US: B
'
V2_SERVICE_ENUS='name: s
services:
  a:
    image: x
    x-casaos:
      envs:
        - container: FOO
          description:
            en_us: bad
x-casaos:
  id: com.bigbeartechworld.s
  category: Media
  title:
    en_US: S
'

# detect: v1-only tree -> migrated=false
R="$(mktemp -d)"; mkapp "$R" v1 "$V1_APP"
out=$(bash "$DETECT" "$R"); [[ "$out" == "migrated=false" ]] && pass "detect false on v1-only" || bad "detect on v1-only ($out)"
rm -rf "$R"

# detect: any v2 app -> migrated=true
R="$(mktemp -d)"; mkapp "$R" c "$V2_CLEAN"; mkapp "$R" v1 "$V1_APP"
out=$(bash "$DETECT" "$R"); [[ "$out" == "migrated=true" ]] && pass "detect true when a v2 app present" || bad "detect mixed ($out)"
rm -rf "$R"

# detect: GITHUB_OUTPUT written
R="$(mktemp -d)"; GO="$(mktemp)"; mkapp "$R" c "$V2_CLEAN"
GITHUB_OUTPUT="$GO" bash "$DETECT" "$R" >/dev/null
grep -qx "migrated=true" "$GO" && pass "detect writes GITHUB_OUTPUT" || bad "GITHUB_OUTPUT not written"
rm -rf "$R"; rm -f "$GO"

# lint: v1 app skipped -> pass (transition-safe)
R="$(mktemp -d)"; mkapp "$R" v1 "$V1_APP"
bash "$LINT" "$R" >/dev/null; [[ $? -eq 0 ]] && pass "lint skips v1 app (exit 0)" || bad "lint failed on v1 app"
rm -rf "$R"

# lint: clean v2 -> pass
R="$(mktemp -d)"; mkapp "$R" c "$V2_CLEAN"
bash "$LINT" "$R" >/dev/null; [[ $? -eq 0 ]] && pass "lint passes clean v2" || bad "lint failed clean v2"
rm -rf "$R"

# lint: v2 with bad id -> fail
R="$(mktemp -d)"; mkapp "$R" b "$V2_BAD_ID"
bash "$LINT" "$R" >/dev/null; [[ $? -eq 1 ]] && pass "lint fails bad id" || bad "lint missed bad id"
rm -rf "$R"

# lint: v2 with service-level en_us -> fail (whole-file scan)
R="$(mktemp -d)"; mkapp "$R" s "$V2_SERVICE_ENUS"
bash "$LINT" "$R" >/dev/null; [[ $? -eq 1 ]] && pass "lint fails service-level en_us" || bad "lint missed service en_us"
rm -rf "$R"

exit $fail
