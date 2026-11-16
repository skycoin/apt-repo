#!/usr/bin/bash
#update skywire-bin debian package
_aptrepo="apt-repo"
[[ ! -f "$(pwd)/${BASH_SOURCE}" ]] && echo "please execute this script in the same working dir" && exit 1
[[ "$(pwd)" != ${HOME}/go/src/github.com/skycoin/${_aptrepo} ]] && echo "please move the cloned repository to $HOME/go/src/github.com/skycoin/${_aptrepo}" && exit 1
[[ -f skywire-bin*.deb ]] && rm skywire-bin*.deb
[[ -f skywire-tinygo-bin*.deb ]] && rm skywire-tinygo-bin*.deb
[[ ! -d $HOME/.cache/yay/skywire-bin ]] && printf '%s\n' Ab | yay -Syy skywire-bin #its not necessary to actually install it
cd $HOME/.cache/yay/skywire-bin || exit 1
git reset --hard
git pull
updpkgsums
updpkgsums cc.deb.PKGBUILD
makepkg -Cfp cc.deb.PKGBUILD || exit 1
# skywire-tinygo-bin, from the release's -tinygo archives (experimental)
updpkgsums tinygo.deb.PKGBUILD
makepkg -Cfp tinygo.deb.PKGBUILD || exit 1
mv skywire-bin*.deb $HOME/go/src/github.com/skycoin/${_aptrepo}/ || exit 1
mv skywire-tinygo-bin*.deb $HOME/go/src/github.com/skycoin/${_aptrepo}/ || exit 1
cd $HOME/go/src/github.com/skycoin/${_aptrepo}/ || exit 1
reprepro -Vb . remove sid skywire-bin || exit 1
reprepro -Vb . includedeb sid skywire-bin*.deb || exit 1
reprepro -Vb . remove sid skywire-tinygo-bin || true
reprepro -Vb . includedeb sid skywire-tinygo-bin*.deb || exit 1
[[ ! -d ./.archive ]] && mkdir ./.archive
mv skywire-bin*.deb ./.archive/
mv skywire-tinygo-bin*.deb ./.archive/
#echo "now sign the release file"
