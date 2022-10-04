#!/usr/bin/bash
#update skybian debian package
[[ ! -f "$(pwd)/${BASH_SOURCE}" ]] && echo "please execute this script in the same working dir" && exit 1
[[ "$(pwd)" != ${HOME/home/home*}/go/src/github.com/skycoin/apt-repo ]] && echo "please move the cloned repository to $HOME/go/src/github.com/skycoin/apt-repo" && exit 1
[[ -f skybian*.deb ]] && rm skybian*.deb
[[ ! -d $HOME/go/src/github.com/skycoin/skybian/ ]] && [[ ! -f $HOME/go/src/github.com/skycoin/skybian/PKGBUILD ]] && echo "skybian repo not detected in expected GOPATH; cloning to $HOME/go/src/github.com/skycoin/skybian" mkdir -p $HOME/go/src/github.com/skycoin/ && cd $HOME/go/src/github.com/skycoin/ && git clone https://github.com/skycoin/skybian
cd $HOME/go/src/github.com/skycoin/skybian/ || exit 1
[[ -f skybian*.deb ]] && rm skybian*.deb
git fetch
git checkout master
git reset --hard  #discard anything not comited
git pull || exit 1
./skybian.sh || exit 1
cp skybian*.deb $HOME/go/src/github.com/skycoin/apt-repo/ || exit 1
cd $HOME/go/src/github.com/skycoin/apt-repo/ || exit 1
reprepro -Vb . remove sid skybian || exit 1
reprepro -Vb . includedeb sid skybian*.deb || exit 1
[[ ! -d archive ]] && mkdir archive
[[ -f archive/skybian*.deb ]] && rm archive/skybian*.deb
mv skybian*.deb archive/
cp -b archive/skybian-*-amd64.deb archive/skybian-amd64.deb
cp -b archive/skybian-*-arm64.deb archive/skybian-arm64.deb
cp -b archive/skybian-*-armhf.deb archive/skybian-armhf.deb
cp -b archive/skybian-*-armel.deb archive/skybian-armel.deb
#echo "now sign the release file"
