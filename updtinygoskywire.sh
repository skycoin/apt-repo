#!/usr/bin/bash
# Build the tinygo-skywire Arch and Debian packages from the current
# 0magnet/tinygo toolchain release and upload them to the tinygo-skywire
# release of skycoin/apt-repo. They are too large for the Pages repo, so
# they are not added to the apt or pacman DBs.
set -e
_aptrepo="apt-repo"
[[ "$(pwd)" != ${HOME}/go/src/github.com/skycoin/${_aptrepo} ]] && echo "run from $HOME/go/src/github.com/skycoin/${_aptrepo}" && exit 1
KEY=48F19E5157BE6014D80A47328D6D51BC4AD7AE64
FORK=0magnet/tinygo
REL=tinygo-skywire
APT="$(pwd)"
WORK="${TMPDIR:-/tmp}/tinygo-skywire-build"
URL="https://github.com/${FORK}/releases/download/toolchain/tinygo.linux-amd64.tar.gz"

rm -rf "$WORK" && mkdir -p "$WORK/out"
cd "$WORK"
_sha=$(gh release view toolchain --repo "$FORK" --json targetCommitish -q .targetCommitish)
curl -fsSL -o tinygo.linux-amd64.tar.gz "$URL"
curl -fsSL "$URL.sha256" | awk '{print $1"  tinygo.linux-amd64.tar.gz"}' | sha256sum -c
# The release tag moves, so check it still points at the commit we read.
[[ "$(gh release view toolchain --repo "$FORK" --json targetCommitish -q .targetCommitish)" == "$_sha" ]] || { echo "toolchain release moved during download, rerun"; exit 1; }
_ver=$(gh api "repos/${FORK}/contents/goenv/version.go?ref=${_sha}" -q .content | base64 -d | sed -n 's/^const version = "\(.*\)"$/\1/p')
_date=$(gh api "repos/${FORK}/commits/${_sha}" -q .commit.committer.date | cut -c1-10 | tr -d -)
pkgver="${_ver}+git${_date}.${_sha:0:9}"
echo "tinygo-skywire ${pkgver}"

for f in tinygo-skywire.PKGBUILD tinygo-skywire.deb.PKGBUILD; do
	sed "s/^pkgver=.*/pkgver=${pkgver}/" "$APT/$f" > "$WORK/$f"
done
export SRCDEST="$WORK" PKGDEST="$WORK/out" BUILDDIR="$WORK/build"
makepkg -f -p tinygo-skywire.deb.PKGBUILD
makepkg -f -p tinygo-skywire.PKGBUILD --sign --key "$KEY"
gpg --batch --yes --detach-sign -u "$KEY" out/*.deb
ls -l out

gh release view "$REL" --repo skycoin/${_aptrepo} >/dev/null 2>&1 || gh release create "$REL" --repo skycoin/${_aptrepo} --title "tinygo-skywire" --notes "TinyGo from the ${FORK} develop branch, packaged for Arch (x86_64) and Debian (amd64). Built by updtinygoskywire.sh. Signed with the Skycoin key."
gh release upload "$REL" --repo skycoin/${_aptrepo} --clobber out/*
# Keep only the packages just uploaded.
for a in $(gh release view "$REL" --repo skycoin/${_aptrepo} --json assets -q '.assets[].name'); do
	[[ -f "out/$a" ]] || gh release delete-asset "$REL" "$a" --repo skycoin/${_aptrepo} -y
done
gh release edit "$REL" --repo skycoin/${_aptrepo} --notes "TinyGo ${pkgver} from ${FORK} commit ${_sha}, packaged for Arch (x86_64) and Debian (amd64). Built by updtinygoskywire.sh. Signed with the Skycoin key."
rm -rf "$WORK"
