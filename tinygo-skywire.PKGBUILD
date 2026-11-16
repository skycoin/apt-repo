# TinyGo built from the 0magnet/tinygo develop branch, repackaged from the
# fork's toolchain release. Run updtinygoskywire.sh, which sets pkgver and
# the checksum and publishes to the tinygo-skywire release of this repo.
pkgname=tinygo-skywire
pkgver=0.0.0
pkgrel=1
pkgdesc="TinyGo from the 0magnet/tinygo fork, as used to build skywire (static, LLVM built in)"
arch=('x86_64')
url="https://github.com/0magnet/tinygo"
license=('BSD-3-Clause')
depends=('go')
provides=('tinygo')
conflicts=('tinygo')
options=('!strip' '!debug')
source=("tinygo.linux-amd64.tar.gz")
sha256sums=('SKIP')

package() {
	install -d "${pkgdir}/opt" "${pkgdir}/usr/bin"
	cp -a "${srcdir}/tinygo" "${pkgdir}/opt/tinygo-skywire"
	ln -s /opt/tinygo-skywire/bin/tinygo "${pkgdir}/usr/bin/tinygo"
}
