#!/usr/bin/bash
#update skywire debian package - this is built outside the release pipeline ; directly crosscompiled from AUR
[[ ! -f "$(pwd)/${BASH_SOURCE}" ]] && echo "please execute this script in the same working dir" && exit 1
[[ "$(pwd)" != ${HOME}/go/src/github.com/skycoin/apt-repo ]] && echo "please move the cloned repository to $HOME/go/src/github.com/skycoin/apt-repo" && exit 1
[[ -f skywire*.deb ]] && rm skywire*.deb
[[ ! -d $HOME/.cache/yay/skywire ]] && printf '%s\n' Ab | yay -Syy skywire #its not necessary to actually install it
cd $HOME/.cache/yay/skywire || exit 1
git pull
makepkg -fp cc.deb.PKGBUILD || exit 1
mv skywire*.deb $HOME/go/src/github.com/skycoin/apt-repo/ || exit 1
cd $HOME/go/src/github.com/skycoin/apt-repo/ || exit 1
reprepro -Vb . remove sid skywire || exit 1
reprepro -Vb . includedeb sid skywire*.deb || exit 1
[[ ! -d archive ]] && mkdir archive
mv skywire*.deb archive/
#echo "now sign the release file"
