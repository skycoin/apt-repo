#!/usr/bin/bash
#update skywire-bin debian package
[[ -f *.deb ]] && rm *.deb
cd ~/.cache/yay/skywire-bin || yay -Syy skywire-bin #its not necessary to actually install it
git pull
makepkg -fp cc.deb.PKGBUILD || exit 1
mv *.deb $HOME/go/src/github.com/skycoin/apt-repo/
cd $HOME/go/src/github.com/skycoin/apt-repo/
reprepro remove sid skywire-bin
reprepro includedeb sid *.deb
[[ ! -d archive ]] && mkdir archive
mv *.deb archive/
#echo "now sign the release file"
