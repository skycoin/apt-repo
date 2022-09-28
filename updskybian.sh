#!/usr/bin/bash
#update skybian debian package
rm *.deb
cd $HOME/go/src/github.com/skycoin/skybian/
git fetch
git reset --hard
git checkout master
git pull
./skybian.sh
cp -b skybian*.deb $HOME/go/src/github.com/skycoin/apt-repo/
cd $HOME/go/src/github.com/skycoin/apt-repo/
reprepro remove sid skybian
reprepro includedeb sid *.deb
rm archive/skybian*.deb
mv *.deb archive/
cp -b archive/skybian-*-amd64.deb archive/skybian-amd64.deb
cp -b archive/skybian-*-arm64.deb archive/skybian-arm64.deb
cp -b archive/skybian-*-armhf.deb archive/skybian-armhf.deb
cp -b archive/skybian-*-armel.deb archive/skybian-armel.deb
#echo "now sign the release file"
