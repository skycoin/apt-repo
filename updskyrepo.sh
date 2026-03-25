#!/usr/bin/bash
#update skyrepo debian package
#_aptrepo="apt-repo"
#[[ ! -f "$(pwd)/${BASH_SOURCE}" ]] && echo "please execute this script in the same working dir" && exit 1
#[[ "$(pwd)" != ${HOME}/go/src/github.com/skycoin/${_aptrepo} ]] && echo "please move the cloned repository to $HOME/go/src/github.com/skycoin/${_aptrepo}" && exit 1
#[[ -f skywire-bin*.deb ]] && rm skywire-bin*.deb
#[[ ! -d $HOME/.cache/yay/skywire-bin ]] && printf '%s\n' Ab | yay -Syy skywire-bin #its not necessary to actually install it
#cd $HOME/.cache/yay/skywire-bin || exit 1
#git pull
#makepkg -fp skyrepo.PKGBUILD || exit 1
#mv skyrepo*.deb $HOME/go/src/github.com/skycoin/${_aptrepo}/ || exit 1
#cd $HOME/go/src/github.com/skycoin/${_aptrepo}/ || exit 1
set -x
makepkg -f
reprepro -Vb . remove sid skyrepo || exit 1
reprepro -Vb . remove sid skybian || exit 1
reprepro -Vb . includedeb sid skyrepo*.deb || exit 1
[[ ! -d archive ]] && mkdir archive
mv skyrepo*.deb archive/
cp -b archive/skyrepo-*-amd64.deb archive/skyrepo-amd64.deb
cp -b archive/skyrepo-*-arm64.deb archive/skyrepo-arm64.deb
cp -b archive/skyrepo-*-armhf.deb archive/skyrepo-armhf.deb
cp -b archive/skyrepo-*-armel.deb archive/skyrepo-armel.deb
cp -b archive/skyrepo-*-riscv64.deb archive/skyrepo-riscv64.deb
#echo "now sign the release file"
set +x
