#!/bin/bash

set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/pacman" <<'SH'
#!/bin/bash
[[ $* == "-Qq" ]] || exit 91
[[ ${QUERY_FAIL:-0} == 0 ]] || exit 1
printf '%s\n' "$PACKAGES"
SH
chmod +x "$tmp/pacman"
export PATH="$tmp:$PATH"
for kernel in linux-asahi linux-aurora linux-omarchy-m4-research; do
  [[ $(PACKAGES="$kernel" "$ROOT/bin/omarchy-mac-kernel") == "$kernel" ]] || fail "installed $kernel is selected"
done
for packages in '' linux $'linux-asahi\nlinux-aurora' $'linux-aurora\nlinux-omarchy-m4-research'; do
  if PACKAGES="$packages" "$ROOT/bin/omarchy-mac-kernel"; then fail "missing or ambiguous kernel is refused"; fi
done
if QUERY_FAIL=1 PACKAGES=linux-asahi "$ROOT/bin/omarchy-mac-kernel"; then fail "package query failure is refused"; fi
pass "kernel selection uses installed packages and refuses missing or ambiguous results"

both=$'linux-aurora\nlinux-omarchy-m4-research'
for kernel in linux-aurora linux-omarchy-m4-research; do
  [[ $(PACKAGES="$both" "$ROOT/bin/omarchy-mac-kernel" --select "$kernel") == "$kernel" ]] ||
    fail "an explicitly selected installed kernel is returned"
done
if PACKAGES="$both" "$ROOT/bin/omarchy-mac-kernel" --select linux-asahi >/dev/null 2>&1; then
  fail "an explicitly selected but absent kernel is refused"
fi
if PACKAGES="$both" "$ROOT/bin/omarchy-mac-kernel" --select linux-other >/dev/null 2>&1; then
  fail "an unknown kernel is refused"
fi
if QUERY_FAIL=1 PACKAGES="$both" "$ROOT/bin/omarchy-mac-kernel" --select linux-aurora >/dev/null 2>&1; then
  fail "explicit selection still requires the package database"
fi
if PACKAGES="$both" "$ROOT/bin/omarchy-mac-kernel" --select linux-aurora extra >/dev/null 2>&1; then
  fail "unexpected selection arguments are refused"
fi
pass "explicit kernel selection is read-only and requires the exact installed package"
