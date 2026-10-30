#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
"$ROOT/install" "$tmp/staged"
hook="$tmp/staged/usr/share/libalpm/hooks/05-omarchy-mac-m4-research-guard.hook"
guard="$tmp/staged/usr/lib/omarchy-mac/boot/m4-research-transaction-guard"
coexistence_hook="$tmp/staged/usr/share/libalpm/hooks/06-omarchy-mac-m4-coexistence-guard.hook"
coexistence_guard="$tmp/staged/usr/lib/omarchy-mac/boot/m4-coexistence-guard"
[[ -f $hook && -x $guard && -f $coexistence_hook && -x $coexistence_guard ]] ||
  fail "the M4 transaction hooks and executable guards are staged"
if "$guard" >"$tmp/out" 2>&1; then
  fail "the unqualified research transaction is refused"
fi
grep -Fq 'not qualified for installation or upgrade' "$tmp/out" || fail "the guard explains the refusal"
mkdir "$tmp/bin"
cat >"$tmp/bin/pacman" <<'SH'
#!/bin/sh
[ "$1" = -Qq ] || exit 2
[ "${TEST_PACMAN_FAIL:-0}" = 0 ] || exit 1
printf '%s\n' "$TEST_PACKAGES"
SH
chmod +x "$tmp/bin/pacman"
TEST_PACKAGES=$'linux-aurora\nm1n1-aurora' PATH="$tmp/bin:$PATH" "$coexistence_guard" ||
  fail "normal Apple kernel and loader transactions remain allowed"
for name in linux-omarchy-m4-research m1n1-omarchy-m4-research; do
  if TEST_PACKAGES=$'linux-aurora\n'"$name" PATH="$tmp/bin:$PATH" "$coexistence_guard" >"$tmp/out" 2>&1; then
    fail "an m1n1-triggering transaction is refused when $name is installed"
  fi
done
if TEST_PACKAGES='' TEST_PACMAN_FAIL=1 PATH="$tmp/bin:$PATH" "$coexistence_guard" >"$tmp/out" 2>&1; then
  fail "an unreadable package database is refused"
fi
pass "the M4 guards refuse research packages and unsafe coexistence transactions"
