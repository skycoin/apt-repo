#!/usr/bin/bash
#update skywire-docker-autopull debian package
_aptrepo="apt-repo"
[[ ! -f "$(pwd)/${BASH_SOURCE}" ]] && echo "please execute this script in the same working dir" && exit 1
[[ "$(pwd)" != ${HOME}/go/src/github.com/skycoin/${_aptrepo} ]] && echo "please move the cloned repository to $HOME/go/src/github.com/skycoin/${_aptrepo}" && exit 1
[[ -f skywire-docker-autopull*.deb ]] && rm skywire-docker-autopull*.deb
[[ ! -d $HOME/.cache/yay/skywire-bin ]] && printf '%s\n' Ab | yay -Syy skywire-bin #its not necessary to actually install it
cd $HOME/.cache/yay/skywire-bin || exit 1
git reset --hard
git pull
# Debian package
makepkg -fp docker-autopull.deb.PKGBUILD || exit 1
mv skywire-docker-autopull*.deb ${HOME}/go/src/github.com/skycoin/${_aptrepo}/ || exit 1
# Arch package (arch=any) — signed, published into every per-arch pacman DB
KEY=48F19E5157BE6014D80A47328D6D51BC4AD7AE64
makepkg -fp docker-autopull.PKGBUILD --nodeps --sign --key "$KEY" || exit 1
_arch_pkg=$(ls -1 skywire-docker-autopull-*-any.pkg.tar.zst | head -1)
cp -f "$_arch_pkg" "$_arch_pkg.sig" ${HOME}/go/src/github.com/skycoin/${_aptrepo}/ 2>/dev/null || cp -f "$_arch_pkg" ${HOME}/go/src/github.com/skycoin/${_aptrepo}/
cd ${HOME}/go/src/github.com/skycoin/${_aptrepo}/ || exit 1
reprepro -Vb . remove sid skywire-docker-autopull 2>/dev/null || true
reprepro -Vb . includedeb sid skywire-docker-autopull*.deb || exit 1
./pacmanaddany.sh "$(pwd)/$(basename "$_arch_pkg")" || exit 1
[[ ! -d .archive ]] && mkdir .archive
mv skywire-docker-autopull*.deb .archive/
mv skywire-docker-autopull-*-any.pkg.tar.zst .archive/ 2>/dev/null || true
mv skywire-docker-autopull-*-any.pkg.tar.zst.sig .archive/ 2>/dev/null || true
