#!/usr/bin/bash
# Build + publish the skyrepo package for BOTH distros:
#   - Debian: skyrepo.deb.PKGBUILD  -> reprepro includedeb (apt repo)
#   - Arch:   PKGBUILD              -> repo-add into archlinux/<arch>/ (pacman repo)
# Both configure the signed Skycoin package repo + key for their package manager.
# Publishing is a separate step: ./updgithub.sh (git push to Pages) is the deploy.
set -e
KEY=48F19E5157BE6014D80A47328D6D51BC4AD7AE64
_aptrepo="apt-repo"
[[ "$(pwd)" != ${HOME}/go/src/github.com/skycoin/${_aptrepo} ]] && echo "run from $HOME/go/src/github.com/skycoin/${_aptrepo}" && exit 1

# ---- Debian skyrepo (.deb) ----
rm -f skyrepo.deb
makepkg -cf -p skyrepo.deb.PKGBUILD
reprepro -Vb . remove sid skyrepo || true
reprepro -Vb . includedeb sid skyrepo*.deb || exit 1
[[ ! -d .archive ]] && mkdir .archive
cp skyrepo*.deb .archive/
mv skyrepo*.deb skyrepo.deb

# ---- Arch skyrepo (pacman, arch=any) ----
# Default PKGBUILD is the Arch skyrepo; build + sign, then publish into every DB.
makepkg -cf --sign --key "$KEY" -p PKGBUILD
pkg=$(ls -1 skyrepo-*-any.pkg.tar.zst | head -1)
./pacmanaddany.sh "$(pwd)/$pkg"
mv skyrepo-*-any.pkg.tar.zst .archive/ 2>/dev/null || true
mv skyrepo-*-any.pkg.tar.zst.sig .archive/ 2>/dev/null || true

echo ">> skyrepo staged for apt + pacman. Publish with ./updgithub.sh"
