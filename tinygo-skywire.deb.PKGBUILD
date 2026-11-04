# Debian package of tinygo-skywire.PKGBUILD. Run updtinygoskywire.sh.
pkgname=tinygo-skywire
pkgver=0.0.0
pkgrel=1
pkgdesc="TinyGo from the 0magnet/tinygo fork, as used to build skywire (static, LLVM built in)"
arch=('x86_64')
_pkgarch='amd64'
url="https://github.com/0magnet/tinygo"
license=('BSD-3-Clause')
makedepends=('dpkg')
options=('!strip' '!debug')
source=("tinygo.linux-amd64.tar.gz")
sha256sums=('SKIP')

package() {
	_debpkgdir="${pkgname}-${pkgver}-${pkgrel}-${_pkgarch}"
	_pkgdir="${pkgdir}/${_debpkgdir}"
	install -d "${_pkgdir}/opt" "${_pkgdir}/usr/bin" "${_pkgdir}/DEBIAN"
	cp -a "${srcdir}/tinygo" "${_pkgdir}/opt/tinygo-skywire"
	ln -s /opt/tinygo-skywire/bin/tinygo "${_pkgdir}/usr/bin/tinygo"
	cat > "${_pkgdir}/DEBIAN/control" <<CTRL
Package: ${pkgname}
Version: ${pkgver}-${pkgrel}
Priority: optional
Section: devel
Architecture: ${_pkgarch}
Provides: tinygo
Conflicts: tinygo
Replaces: tinygo
Recommends: golang-go
Maintainer: Skycoin
Description: ${pkgdesc}
CTRL
	cd "${pkgdir}"
	dpkg-deb --root-owner-group --build -Zxz "${_debpkgdir}"
	mv ./*.deb "${PKGDEST:-${startdir}}/"
	rm -rf "${srcdir}"
	# exit so makepkg does not also build an arch package
	exit
}
