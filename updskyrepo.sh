#!/usr/bin/bash
#update skyrepo debian packages
set -x
rm skyrepo.deb
makepkg -cf
reprepro -Vb . remove sid skyrepo || exit 1
reprepro -Vb . includedeb sid skyrepo*.deb || exit 1
[[ ! -d archive ]] && mkdir archive
cp skyrepo*.deb archive/
mv skyrepo*.deb skyrepo.deb
#echo "now sign the release file"
set +x
