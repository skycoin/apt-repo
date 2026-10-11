#!/usr/bin/bash
# Publish the apt-repo + install-command generator to GitHub Pages.
#
# Before pushing, refresh the skywire dependency and rebuild the
# WASM-backed install page so the published generator/index.html
# reflects the current skywire `autoconfig` flag set (the form is
# generated live from pkg/skywireconfig/autoconfigcmd via the TinyGo
# wasm — see Makefile / cmd/wasm).
#
# `make update` bumps skywire to its latest RELEASE TAG, then
# `make all` rebuilds the TinyGo wasm and re-renders the page. The
# release-tag pin is deliberate: the flags shown then match what
# `apt install skywire-bin` / `yay -S skywire-bin` / the Windows MSI
# actually deliver, and the MSI download URL (which embeds the
# version) stays valid.
#
# To pin the published page to develop HEAD instead — e.g. to surface
# autoconfig flag changes merged to develop but not yet released —
# export SKYWIRE_REF for this script (it propagates to `make update`):
#
#     SKYWIRE_REF=develop ./updgithub.sh
#
set -e

# Refresh skywire dep + rebuild wasm + re-render generator/index.html.
make update

# Force-push the whole tree as a single commit (GitHub Pages branch).
rm -rf .git
git init
git add .gitignore
git add --all
git commit -m "updated packages"
git remote add origin git@github.com:skycoin/apt-repo.git
git push -u --force origin master
