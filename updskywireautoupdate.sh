#!/usr/bin/bash
#update skywire-autoupdate debian package
_aptrepo="apt-repo"
[[ ! -f "$(pwd)/${BASH_SOURCE}" ]] && echo "please execute this script in the same working dir" && exit 1
[[ "$(pwd)" != ${HOME}/go/src/github.com/skycoin/${_aptrepo} ]] && echo "please move the cloned repository to $HOME/go/src/github.com/skycoin/${_aptrepo}" && exit 1
[[ -f skywire-autoupdate*.deb ]] && rm skywire-autoupdate*.deb
[[ ! -d $HOME/.cache/yay/skywire-bin ]] && printf '%s\n' Ab | yay -Syy skywire-bin #its not necessary to actually install it
cd $HOME/.cache/yay/skywire-bin || exit 1
git reset --hard
git pull
makepkg -fp autoupdate.deb.PKGBUILD || exit 1
mv skywire-autoupdate*.deb ${HOME}/go/src/github.com/skycoin/${_aptrepo}/ || exit 1
cd ${HOME}/go/src/github.com/skycoin/${_aptrepo}/ || exit 1
reprepro -Vb . remove sid skywire-autoupdate 2>/dev/null || true
reprepro -Vb . includedeb sid skywire-autoupdate*.deb || exit 1
[[ ! -d archive ]] && mkdir archive
mv skywire-autoupdate*.deb archive/
