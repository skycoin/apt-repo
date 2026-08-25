# Maintainer: Moses Narrow <moe_narrow@use.startmail.com>
#
# Arch (pacman) skyrepo package — the pacman analogue of skyrepo.deb.PKGBUILD.
# Where the .deb ships an apt sources.list + trusted.gpg.d key, this ships the
# Skycoin packaging pubkey and an install scriptlet that imports+lsigns it into
# pacman's keyring and appends the signed [skywire] repo to /etc/pacman.conf —
# so `pacman -Sy skywire-bin skywire-autoupdate` works with SigLevel=Required,
# root-level, no AUR build. This is exactly what the deb.skywire.dev /generator/
# "pacman repo" tab emits, packaged so it survives reinstalls and is itself
# kept current from the repo.
#
# pkgver tracks the skywire-bin / skywire release version, in lockstep with
# skyrepo.deb.PKGBUILD, so the repo presents a single coherent version line.
pkgname=skyrepo
pkgdesc="Skycoin signed pacman repo configuration + signing key (Arch): wires up the [skywire] pacman repo"
pkgver=1.3.92
pkgrel=1
arch=('any')
url="https://github.com/skycoin/skyrepo"
license=('custom:license-free')
install=skyrepo.install
source=()
sha256sums=()

build() {
	# Export the Skycoin packaging pubkey that signs the [skywire] repo DB and
	# every package in it. Same key as the apt repo (KEY.asc / skywire-pacman.gpg).
	gpg --export 48F19E5157BE6014D80A47328D6D51BC4AD7AE64 > "${srcdir}/skywire-pacman.gpg"
}

package() {
	install -Dm644 "${srcdir}/skywire-pacman.gpg" "${pkgdir}/usr/share/skyrepo/skywire-pacman.gpg"
}
