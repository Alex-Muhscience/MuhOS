#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# MuhOS installer: downloads the newest MuhOS release from GitHub, checks it
# against the release's SHA256SUMS, and installs it with dnf. Running it again
# updates MuhOS.
#
#   curl -fsSL https://alex-muhscience.github.io/MuhOS/install.sh | bash
#
# Options (pass them with: curl -fsSL … | bash -s -- --yes):
#   --yes          don't ask before installing (dnf runs with -y)
#   --tag TAG      install a specific release, e.g. v0.1.0-pre.4
#   --keep DIR     keep the downloaded packages in DIR
#   --dry-run      download and verify only; install nothing
#
# What it changes: enables the lionheartp/Hyprland COPR (Hyprland is not in
# Fedora) and installs the MuhOS packages. Nothing else; your GNOME session
# and settings stay as they are.
#
# Everything is inside main(), called on the last line, so a download cut
# off halfway runs nothing.

set -euo pipefail

REPO="Alex-Muhscience/MuhOS"
COPR="lionheartp/Hyprland"

say() { printf '\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

main() {
    local yes=false tag="" keep="" dry_run=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --yes|-y) yes=true ;;
            --tag) tag="${2:?--tag needs a release tag}"; shift ;;
            --keep) keep="${2:?--keep needs a directory}"; shift ;;
            --dry-run) dry_run=true ;;
            -h|--help)
                echo "usage: install.sh [--yes] [--tag TAG] [--keep DIR] [--dry-run]"
                exit 0 ;;
            *) fail "unknown option: $1" ;;
        esac
        shift
    done

    # Questions and dnf read the terminal: when piped from curl, standard
    # input is this script itself and must not be read by anything else.
    local tty=/dev/tty
    if ! { : < /dev/tty; } 2>/dev/null; then
        $yes || $dry_run || fail "no terminal to ask on; run again with: bash -s -- --yes"
        tty=/dev/null
    fi

    # 1. This system
    [ -r /etc/os-release ] || fail "cannot tell which Linux this is (/etc/os-release is missing)"
    local ID="" VERSION_ID="" PRETTY_NAME=""
    # shellcheck disable=SC1091
    . /etc/os-release
    [ "$ID" = fedora ] || fail "MuhOS packages are for Fedora; this is ${PRETTY_NAME:-unknown}"
    [ "$VERSION_ID" = 44 ] || fail "MuhOS packages are built for Fedora 44; this is Fedora ${VERSION_ID:-?}"
    [ "$(uname -m)" = x86_64 ] || fail "MuhOS packages are for x86_64; this is $(uname -m)"
    local tool
    for tool in curl sha256sum python3 dnf sudo; do
        command -v "$tool" >/dev/null || fail "$tool is needed"
    done

    # 2. The release
    local api
    if [ -n "$tag" ]; then
        api="https://api.github.com/repos/$REPO/releases/tags/$tag"
    else
        api="https://api.github.com/repos/$REPO/releases?per_page=1"   # includes pre-releases
    fi
    say "Looking up the ${tag:-newest} MuhOS release…"
    local release_json
    release_json="$(curl -fsSL -H "Accept: application/vnd.github+json" "$api" < /dev/null)" \
        || fail "could not reach GitHub"
    local -a release
    mapfile -t release < <(python3 -I -c '
import json, sys
r = json.load(sys.stdin)
if isinstance(r, list):
    r = r[0] if r else None
if not r:
    sys.exit("no releases found")
print(r["tag_name"])
print(r.get("name") or r["tag_name"])
for a in r.get("assets", []):
    n = a["name"]
    if n == "SHA256SUMS" or (n.endswith((".noarch.rpm", ".x86_64.rpm")) and not n.endswith(".src.rpm")):
        print(n + "\t" + a["browser_download_url"])
' <<< "$release_json")
    [ ${#release[@]} -ge 2 ] || fail "could not read the release information"
    tag="${release[0]}"
    say "Found ${release[1]} ($tag)."

    # 3. Download and verify
    local work
    work="$(mktemp -d)"
    # shellcheck disable=SC2064   # expand now: $work is local
    trap "rm -rf '$work'" EXIT
    local -a files=()
    local line name url
    for line in "${release[@]:2}"; do
        name="${line%%$'\t'*}"
        url="${line#*$'\t'}"
        [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || fail "unexpected file name in the release: $name"
        printf '  downloading %s\n' "$name"
        curl -fsSL --retry 3 -o "$work/$name" "$url" < /dev/null || fail "download failed: $name"
        [ "$name" = SHA256SUMS ] || files+=("$name")
    done
    [ -f "$work/SHA256SUMS" ] || fail "the release has no SHA256SUMS; not installing unverified packages"
    [ ${#files[@]} -gt 0 ] || fail "the release has no packages for this system"
    say "Checking the downloads against SHA256SUMS…"
    local sums
    sums="$(cd "$work" && for f in "${files[@]}"; do
        awk -v f="$f" '$2 == f || $2 == "*" f' SHA256SUMS | grep . || { echo "missing:$f"; exit 1; }
    done)" || fail "SHA256SUMS does not list every package; nothing was installed"
    (cd "$work" && sha256sum --check --strict --quiet <<< "$sums") \
        || fail "a download does not match SHA256SUMS; nothing was installed"
    echo "  all ${#files[@]} packages match"
    if [ -n "$keep" ]; then
        mkdir -p "$keep"
        cp "$work"/*.rpm "$work/SHA256SUMS" "$keep/"
        echo "  kept in $keep"
    fi
    if $dry_run; then
        say "Dry run: nothing installed."
        return 0
    fi

    # 4. Install
    cat <<EOF

This will:
  - enable the $COPR COPR (Hyprland is not in Fedora's own repositories)
  - install or update: ${files[*]}
dnf will show the full list of changes$($yes || echo " and ask once more") before installing.

EOF
    if ! $yes; then
        local reply
        printf 'Continue? [y/N] ' > /dev/tty
        read -r reply < /dev/tty
        [[ "$reply" =~ ^[Yy] ]] || { echo "Nothing changed."; return 0; }
    fi
    local -a dnf_yes=()
    $yes && dnf_yes=(-y)
    if ! dnf copr list 2>/dev/null < /dev/null | grep -q "$COPR"; then
        # shellcheck disable=SC2024  # dnf reads answers from the terminal, on purpose
        sudo dnf copr enable -y "$COPR" < "$tty"
    fi
    # shellcheck disable=SC2024  # dnf reads answers from the terminal, on purpose
    (cd "$work" && sudo dnf install "${dnf_yes[@]}" "${files[@]/#/./}" < "$tty")

    echo
    say "MuhOS $tag is installed."
    echo 'Log out, click your name on the login screen, choose "MuhOS (Hyprland)"'
    echo "with the gear button at the bottom right, and sign in."
    echo "Docs: https://alex-muhscience.github.io/MuhOS/docs.html"
}

main "$@"
