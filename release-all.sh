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

# Step 1: Update AUR packages
echo "=== Step 1: Update AUR packages ==="

if [[ ! -d "$AUR_DIR" ]]; then
    echo "ERROR: AUR repo not found at $AUR_DIR"
    exit 1
fi

cd "$AUR_DIR"
git pull

echo "--- Updating skywire-bin ---"
cd "${AUR_DIR}/skywire-bin"
_pvernew="${VERSION}" _prelnew=1 ./updates.sh
git add -f *PKGBUILD .SRCINFO skywire-autoconfig *.desktop *.png *.service *.sh *.conf *.install 2>/dev/null || true
git commit -m "bump pkgver ${VERSION}"
aurpublish skywire-bin
git push
echo "DONE: skywire-bin updated in AUR"

echo "--- Updating skywire ---"
cd "${AUR_DIR}/skywire"
_pvernew="${VERSION}" _prelnew=1 ./updates.sh
git add -f *PKGBUILD .SRCINFO skywire.install updates.sh test.sh 2>/dev/null || true
git commit -m "bump pkgver ${VERSION}"
aurpublish skywire
git push
echo "DONE: skywire updated in AUR"

# Step 2: Verify AUR has the update
echo
echo "=== Step 2: Verify AUR propagation ==="
for i in $(seq 1 30); do
    AUR_VER=$(curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=skywire-bin" | python3 -c "import json,sys; print(json.load(sys.stdin)['results'][0]['Version'])" 2>/dev/null || echo "unknown")
    if [[ "$AUR_VER" == *"${VERSION}"* ]]; then
        echo "AUR version confirmed: $AUR_VER"
        break
    fi
    if [[ $i -eq 30 ]]; then
        echo "WARNING: AUR may not have propagated yet (showing $AUR_VER), continuing anyway"
        break
    fi
    echo "Waiting for AUR propagation... ($AUR_VER)"
    sleep 10
done

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
echo
echo "=== Step 5: Deploy to deb.skywire.dev ==="
ssh "${DEPLOY_USER}@${DEPLOY_HOST}" << DEPLOY
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
