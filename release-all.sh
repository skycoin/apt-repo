#!/usr/bin/bash
# Post-release automation: update AUR packages, build .deb, update apt repo, deploy to server.
# Run this from the apt-repo directory after a skywire release has been published on GitHub.
#
# Usage:
#   ./release-all.sh           # auto-detect latest release version
#   ./release-all.sh 1.3.38    # specify version explicitly
#
# Prerequisites:
#   - aurpublish, updpkgsums, makepkg, reprepro installed
#   - SSH key configured for AUR (aur@aur.archlinux.org)
#   - SSH key configured for deb.skywire.dev (skycoin@deb.skywire.dev)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUR_DIR="${HOME}/go/src/github.com/skycoin/aur"
APT_DIR="${HOME}/go/src/github.com/skycoin/apt-repo"
DEPLOY_HOST="deb.skywire.dev"
DEPLOY_USER="skycoin"
DEPLOY_PATH="/home/${DEPLOY_USER}/go/bin/github.com/skycoin"
CADDY_DIR="/usr/share/caddy"

# Ensure we're in the right directory
if [[ "$(pwd)" != "$APT_DIR" ]]; then
    echo "Changing to $APT_DIR"
    cd "$APT_DIR" || { echo "ERROR: apt-repo not found at $APT_DIR"; exit 1; }
fi

# Determine version
if [[ -n "${1:-}" ]]; then
    VERSION="$1"
else
    VERSION=$(git ls-remote --tags --refs --sort="version:refname" https://github.com/skycoin/skywire.git | tail -n1)
    VERSION=${VERSION##*/}
    VERSION=${VERSION%%-*}
    VERSION=${VERSION//v/}
fi

echo "============================================"
echo "  Skywire Release Packaging: v${VERSION}"
echo "============================================"
echo

# aur_publish_package runs aurpublish for the named package and
# explicitly checks the exit code. The previous version relied only
# on `set -e`, which doesn't catch every kind of partial failure
# (aurpublish has historically returned 0 on some auth / push
# rejections). Treating any non-zero exit as fatal so we don't
# proceed to the .deb build using a stale cache.
aur_publish_package() {
    local pkg="$1"
    if ! aurpublish "${pkg}"; then
        echo "ERROR: aurpublish ${pkg} failed (exit $?)" >&2
        exit 1
    fi
}

# wait_for_aur_propagation polls the AUR RPC API for the given
# package name, breaking when its reported Version contains the
# release VERSION. 30 iterations × 10s = 5 min budget. Uses jq for
# JSON parsing (no python3 inline — operator preference).
# Non-fatal: warns on timeout and returns, since the .deb build's
# git pull from the AUR git server is the source of truth and is
# updated synchronously by aurpublish regardless of RPC cache lag.
wait_for_aur_propagation() {
    local pkg="$1"
    for i in $(seq 1 30); do
        local aur_ver
        aur_ver=$(curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=${pkg}" \
            | jq -r '.results[0].Version // "unknown"' 2>/dev/null || echo "unknown")
        if [[ "$aur_ver" == *"${VERSION}"* ]]; then
            echo "  ${pkg}: AUR version confirmed: ${aur_ver}"
            return 0
        fi
        if [[ $i -eq 30 ]]; then
            echo "  WARNING: ${pkg} may not have propagated yet (showing ${aur_ver}), continuing anyway"
            return 0
        fi
        echo "  ${pkg}: waiting for AUR propagation... (${aur_ver})"
        sleep 10
    done
}

# Step 1: Update AUR packages
echo "=== Step 1: Update AUR packages ==="

if [[ ! -d "$AUR_DIR" ]]; then
    echo "ERROR: AUR repo not found at $AUR_DIR"
    exit 1
fi

cd "$AUR_DIR"
git pull

# Order matters: skywire-bin must be published AND propagated to the AUR
# RPC cache before skywire — skywire's PKGBUILD/build steps inspect the
# `skywire-bin` AUR entry (cross-compile sources, .deb companion build),
# so a stale RPC view at the moment skywire is published makes the second
# publish race with the first's propagation. Earlier version of this
# script published both back-to-back then waited at the end; the gap was
# usually fine but occasionally caused skywire's build to pick up an
# inconsistent picture. Interleave: publish bin → wait for propagation →
# publish skywire.
echo "--- Updating skywire-bin ---"
cd "${AUR_DIR}/skywire-bin"
_pvernew="${VERSION}" _prelnew=1 ./updates.sh
git add -f *PKGBUILD .SRCINFO skywire-autoconfig *.desktop *.png *.service *.sh *.conf *.install 2>/dev/null || true
git commit -m "bump pkgver ${VERSION}"
aur_publish_package skywire-bin
git push
echo "DONE: skywire-bin updated in AUR"

echo
echo "=== Step 1b: Wait for skywire-bin AUR propagation ==="
wait_for_aur_propagation skywire-bin

echo
echo "--- Updating skywire ---"
cd "${AUR_DIR}/skywire"
_pvernew="${VERSION}" _prelnew=1 ./updates.sh
git add -f *PKGBUILD .SRCINFO skywire.install updates.sh test.sh 2>/dev/null || true
git commit -m "bump pkgver ${VERSION}"
aur_publish_package skywire
git push
echo "DONE: skywire updated in AUR"

echo
echo "=== Step 2: Wait for skywire AUR propagation ==="
wait_for_aur_propagation skywire

# Step 3: Build .deb and update apt repo
echo
echo "=== Step 3: Build .deb and update apt repo ==="
cd "$APT_DIR"
./updskywirebin.sh
echo "DONE: .deb built and added to reprepro"

# Step 4: Push apt repo to GitHub
echo
echo "=== Step 4: Push apt repo to GitHub ==="
./updgithub.sh
echo "DONE: apt repo pushed to GitHub"

# Step 5: Deploy to server
#
# `-o StrictHostKeyChecking=accept-new` so a first-time run on a fresh
# machine doesn't block waiting for "yes/no" against `deb.skywire.dev`'s
# host key (this fixed an aborted v1.3.60 deploy where the interactive
# prompt swallowed ^C and left the server serving the pre-release pool).
# The host key still gets verified after the first acceptance; this just
# auto-accepts the very first sighting instead of prompting.
echo
echo "=== Step 5: Deploy to deb.skywire.dev ==="
ssh -o StrictHostKeyChecking=accept-new "${DEPLOY_USER}@${DEPLOY_HOST}" << DEPLOY
    set -e
    cd ${DEPLOY_PATH}
    rm -rf apt-repo
    git clone https://github.com/skycoin/apt-repo.git
    cd ${CADDY_DIR}
    find . -maxdepth 1 ! -name archive ! -name . -exec rm -rf {} +
    cp -r ${DEPLOY_PATH}/apt-repo/* .
    echo "Deploy complete"
DEPLOY
echo "DONE: deb.skywire.dev updated"

echo
echo "============================================"
echo "  Release packaging complete: v${VERSION}"
echo "============================================"
