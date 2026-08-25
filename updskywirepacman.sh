#!/usr/bin/bash
# Build + publish the signed pacman (Arch Linux) binary repository under
# ./archlinux/<arch>/ from the SAME AUR skywire-bin PKGBUILD that `yay -S
# skywire-bin` uses — so the hosted package is byte-for-byte what AUR produces,
# just prebuilt centrally and served from a repo so `pacman -Sy skywire-bin`
# updates it as root (no per-device makepkg, no Go toolchain, accurate pacman DB).
#
# This is the pacman analogue of updskywirebin.sh (which does the .deb via
# reprepro). Like the rest of the repo, PUBLISHING is a separate step: this
# script only stages files under ./archlinux/; `./updgithub.sh` (git push to
# Pages) is the actual deploy and remains the last step.
#
# Channel: RELEASE only. The repo tracks the skywire-bin PKGBUILD's pkgver
# (a tagged release). There is deliberately no develop channel here.
#
# Signing: every .pkg.tar.zst and every repo DB is signed with the Skycoin
# packaging key (the same key that signs the apt repo, shipped as KEY.asc and
# exported here as archlinux/skywire-pacman.gpg). Clients use SigLevel=Required.
set -e

_aptrepo="apt-repo"
KEY=48F19E5157BE6014D80A47328D6D51BC4AD7AE64
# pacman CARCH -> which skywire release tarball the PKGBUILD's source_<CARCH> pulls.
# x86_64 builds natively; aarch64/armv7h are packaged foreign (no compile — the
# package is a prebuilt binary, so only CARCH in .PKGINFO + source selection differ).
ARCHES=(x86_64 aarch64 armv7h)

[[ ! -f "$(pwd)/${BASH_SOURCE##*/}" ]] && echo "run this script from the apt-repo checkout root" && exit 1
[[ "$(pwd)" != ${HOME}/go/src/github.com/skycoin/${_aptrepo} ]] && echo "please run from $HOME/go/src/github.com/skycoin/${_aptrepo}" && exit 1

APT="$(pwd)"
AURDIR="$HOME/.cache/yay/skywire-bin"

# Refresh the AUR checkout (same as updskywirebin.sh) so pkgver + sha256sums are current.
[[ ! -d "$AURDIR" ]] && printf '%s\n' Ab | yay -Syy skywire-bin
cd "$AURDIR"
git reset --hard
git pull
updpkgsums

pkgver=$(bash -c 'source ./PKGBUILD; echo "$pkgver"')
pkgrel=$(bash -c 'source ./PKGBUILD; echo "$pkgrel"')
echo ">> building skywire-bin ${pkgver}-${pkgrel} for: ${ARCHES[*]}"

for carch in "${ARCHES[@]}"; do
  echo "--- $carch ---"
  cfg=$(mktemp)
  cat /etc/makepkg.conf > "$cfg"
  echo "CARCH=$carch" >> "$cfg"
  echo "CHOST=${carch}-unknown-linux-gnu" >> "$cfg"
  # -f rebuild, --nodeps (deps are optdepends), --sign with the Skycoin key.
  makepkg --config "$cfg" -f --nodeps --sign --key "$KEY"
  rm -f "$cfg"

  pkg="skywire-bin-${pkgver}-${pkgrel}-${carch}.pkg.tar.zst"
  d="$APT/archlinux/$carch"
  mkdir -p "$d"
  # Drop older versions from the DB dir so Pages doesn't accumulate them
  # (old versions are recoverable from git history / the release tags).
  rm -f "$d"/skywire-bin-*.pkg.tar.zst "$d"/skywire-bin-*.pkg.tar.zst.sig
  cp -f "$pkg" "$pkg.sig" "$d/"
  ( cd "$d" && repo-add -s -k "$KEY" skywire.db.tar.gz "$pkg" )
  # GitHub Pages does not serve symlinks — repo-add makes skywire.db a symlink
  # to skywire.db.tar.gz; replace it (and .files) with real-file copies.
  ( cd "$d"
    for f in skywire.db skywire.db.sig skywire.files skywire.files.sig; do
      [[ -L "$f" ]] && { t=$(readlink "$f"); rm "$f"; cp "$t" "$f"; }
    done )
done

# Export the client trust key next to the repo.
gpg --export --armor "$KEY" > "$APT/archlinux/skywire-pacman.gpg.asc"
gpg --export        "$KEY" > "$APT/archlinux/skywire-pacman.gpg"

echo ">> pacman repo staged under archlinux/. Publish with ./updgithub.sh (git push = deploy)."
