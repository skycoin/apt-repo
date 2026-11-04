#!/usr/bin/bash
# Publish a built arch=any pacman package into every per-arch DB under
# ./archlinux/<arch>/, signed with the Skycoin key, replacing repo-add's
# symlinks with real files (GitHub Pages does not serve symlinks).
#
# arch=any packages (skyrepo, skywire-autoupdate, skywire-docker-autopull) are
# architecture-independent, but pacman resolves each package from the SAME repo
# DB as the machine's $arch — so the one 'any' package must be present in the
# x86_64, aarch64 and armv7h DBs alike. This is the 'any' analogue of the
# per-arch skywire-bin publishing in updskywirepacman.sh.
#
# Usage: ./pacmanaddany.sh /path/to/<pkg>-<ver>-<rel>-any.pkg.tar.zst
set -e

KEY=48F19E5157BE6014D80A47328D6D51BC4AD7AE64
_aptrepo="apt-repo"
[[ "$(pwd)" != ${HOME}/go/src/github.com/skycoin/${_aptrepo} ]] && echo "run from $HOME/go/src/github.com/skycoin/${_aptrepo}" && exit 1

PKGPATH="$1"
[[ -f "$PKGPATH" ]] || { echo "no such package: $PKGPATH"; exit 1; }
APT="$(pwd)"
pkgfile="$(basename "$PKGPATH")"
# Strip -<ver>-<rel>-any.pkg.tar.zst to get the pkgname (for old-version cleanup).
pkgname="$(echo "$pkgfile" | sed -E 's/-[^-]+-[0-9]+-any\.pkg\.tar\.zst$//')"

# Sign the package once (detached), reuse the same .sig for every DB.
[[ -f "$PKGPATH.sig" ]] || gpg --batch --yes --detach-sign -u "$KEY" "$PKGPATH"

for d in "$APT"/archlinux/*/; do
  [[ -d "$d" ]] || continue
  # Drop older versions so Pages doesn't accumulate them.
  rm -f "$d/$pkgname"-*-any.pkg.tar.zst "$d/$pkgname"-*-any.pkg.tar.zst.sig
  cp -f "$PKGPATH" "$PKGPATH.sig" "$d/"
  ( cd "$d" && repo-add -s -k "$KEY" skywire.db.tar.gz "$pkgfile" )
  ( cd "$d"
    for f in skywire.db skywire.db.sig skywire.files skywire.files.sig; do
      [[ -L "$f" ]] && { t=$(readlink "$f"); rm "$f"; cp "$t" "$f"; }
    done )
  echo ">> $pkgfile -> archlinux/$(basename "$d")/"
done
