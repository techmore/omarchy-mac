#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
"$ROOT/install" "$tmp/staged"
hook="$tmp/staged/usr/share/libalpm/hooks/05-omarchy-mac-m4-research-guard.hook"
guard="$tmp/staged/usr/lib/omarchy-mac/boot/m4-research-transaction-guard"
[[ -f $hook && -x $guard ]] || fail "the M4 transaction hook and executable guard are staged"
if "$guard" >"$tmp/out" 2>&1; then
  fail "the unqualified research transaction is refused"
fi
grep -Fq 'not qualified for installation or upgrade' "$tmp/out" || fail "the guard explains the refusal"
pass "the installed M4 package guard refuses unqualified research transactions"
