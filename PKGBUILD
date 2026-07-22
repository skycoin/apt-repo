pkgname=skyrepo
_pkgname=skyrepo
pkgdesc="Skycoin apt repo configuration, signing key, install-skywire service + skybian-style autoconfig payload - debian package"
# Bumped to 1.3.59-1 with the absorption of skybian.deb's role:
# skyrepo now ships skymanager + skybian-reset + motd snippets + skyenv
# defaults, so a skybian.deb is no longer needed. skybian's IMGBUILDs
# install skyrepo + skywire-bin in chroot and that's the whole payload.
#
# pkgver now tracks the skywire-bin / skywire release version (kept in lockstep
# so the apt repo presents a single coherent version line). Bump this to match
# the current skywire-bin package version on each release.
pkgver='1.3.68'
_pkgver=${pkgver}
pkgrel=1
_pkgrel=${pkgrel}
arch=( 'any' )
_pkgarch='all'
_pkgpath="github.com/skycoin/${_pkgname}"
url="https://${_pkgpath}"
makedepends=('dpkg')
depends=()
_debdeps=""
source=()
sha256sums=()
# Local source files (skymanager.sh, *.service, motd snippets) are read
# directly from script/ and static/ via $startdir during package() — they
# live in this repo and don't need to round-trip through $srcdir.

build() {
	#create the apt repo config
	echo 'deb http://deb.skywire.skycoin.com  sid main' > ${srcdir}/skycoin.list
	echo '#deb-src http://deb.skywire.skycoin.com sid main' >> ${srcdir}/skycoin.list
	echo '' >> ${srcdir}/skycoin.list
	echo 'deb http://deb.theskywirenetwork.net  sid main' >> ${srcdir}/skycoin.list
	echo '#deb-src http://deb.theskywirenetwork.net sid main' >> ${srcdir}/skycoin.list
	echo '' >> ${srcdir}/skycoin.list
	echo 'deb http://deb.skywire.dev  sid main' >> ${srcdir}/skycoin.list
	echo '#deb-src http://deb.skywire.dev sid main' >> ${srcdir}/skycoin.list
	#create the pubkey file
	gpg --export 48F19E5157BE6014D80A47328D6D51BC4AD7AE64 > ${srcdir}/skycoin.gpg
	#create the unattended-upgrades example config
	#shipped to /usr/share/doc/skyrepo/examples/ — not enabled by default;
	#operators copy it into /etc/apt/apt.conf.d/ to opt in.
	cat > ${srcdir}/52unattended-upgrades-skycoin <<'EOF'
// Extend unattended-upgrades to cover the Skycoin apt repository.
// Merges with Allowed-Origins from /etc/apt/apt.conf.d/50unattended-upgrades.
// Origin metadata (per `apt-cache policy`):
//   o=skycoin, l=skycoin, n=sid, c=main
Unattended-Upgrade::Origins-Pattern {
    "origin=skycoin,codename=sid";
};
EOF
	#create the periodic-enable example — overrides distros that ship apt's
	#periodic auto-upgrade DISABLED (notably Armbian's 02-armbian-periodic
	#APT::Periodic::Enable "0"). Shipped to examples/, not enabled by default.
	cat > ${srcdir}/99skycoin-periodic <<'EOF'
// Enable apt's periodic unattended upgrades. Sorts last (99) so it wins over
// distros that disable it — notably Armbian's /etc/apt/apt.conf.d/02-armbian-periodic,
// which sets APT::Periodic::Enable "0". Without this the apt-daily-upgrade timer
// fires but the updater no-ops, so skywire-bin (and everything else) never
// auto-upgrades. Copy alongside 52unattended-upgrades-skycoin to opt in.
APT::Periodic::Enable "1";
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
EOF
	#create the systemd drop-in that refreshes the package lists immediately
	#before the daily unattended-upgrade. apt-daily.timer (the list refresh) and
	#apt-daily-upgrade.timer (the install) are INDEPENDENT timers; when the
	#refresh happens to fire after the upgrade on a given day, the upgrade runs
	#against stale lists and a freshly-published skycoin release is missed for a
	#full cycle (observed: boards a day behind on a new release). ExecStartPre
	#here guarantees fresh lists right before every unattended-upgrade so a new
	#release is picked up the SAME day. The leading '-' makes a transient
	#`apt-get update` failure non-fatal, so the upgrade still proceeds against
	#cached lists rather than being blocked by a momentary network hiccup.
	cat > ${srcdir}/skycoin-refresh-before-upgrade.conf <<'EOF'
# Installed by the skyrepo unattended-upgrades opt-in (deb.skywire.dev generator).
# Refresh package lists right before the daily unattended-upgrade so a newly
# published skycoin release is installed same-day instead of lagging a cycle.
[Service]
ExecStartPre=-/usr/bin/apt-get update
EOF
	#README for the examples dir explaining how to enable
	cat > ${srcdir}/EXAMPLES.README <<'EOF'
Skycoin apt-repo: example configuration snippets
================================================

52unattended-upgrades-skycoin
-----------------------------
Optional: extends unattended-upgrades(8) to also pull skywire-bin and
related Skycoin packages on the regular upgrade schedule (typically
nightly via apt-daily-upgrade.timer).

This is NOT enabled by default — installing skyrepo only registers the
apt source. To fully opt in (install the updater, allow the skycoin
origin, AND make sure the periodic timer actually runs):

    sudo apt-get install -y unattended-upgrades
    sudo cp /usr/share/doc/skyrepo/examples/52unattended-upgrades-skycoin \
            /etc/apt/apt.conf.d/
    sudo cp /usr/share/doc/skyrepo/examples/99skycoin-periodic \
            /etc/apt/apt.conf.d/

Verify the origin matches what's in the file by running:

    apt-cache policy | grep -A1 skycoin

To disable later, remove the files:

    sudo rm /etc/apt/apt.conf.d/52unattended-upgrades-skycoin
    sudo rm /etc/apt/apt.conf.d/99skycoin-periodic

99skycoin-periodic
------------------
Forces apt's periodic auto-upgrade ON. Some distros — notably Armbian —
ship /etc/apt/apt.conf.d/02-armbian-periodic with APT::Periodic::Enable
"0", which silently disables apt-daily-upgrade so nothing auto-upgrades
even with 52unattended-upgrades-skycoin in place. This drop-in (sorting
last at 99) re-enables it. Copy it alongside the 52- file above.

skycoin-refresh-before-upgrade.conf  (systemd drop-in)
------------------------------------------------------
apt-daily.timer (refresh package lists) and apt-daily-upgrade.timer (run
the unattended upgrade) are INDEPENDENT — when the refresh fires after the
upgrade on a given day, the upgrade runs against stale lists and a newly
published release is missed for a full cycle (a day or two behind). This
systemd drop-in adds `ExecStartPre=-/usr/bin/apt-get update` to
apt-daily-upgrade.service so the lists are always fresh right before the
upgrade — a new skycoin release is then installed the SAME day. Install:

    sudo mkdir -p /etc/systemd/system/apt-daily-upgrade.service.d
    sudo cp /usr/share/doc/skyrepo/examples/skycoin-refresh-before-upgrade.conf \
            /etc/systemd/system/apt-daily-upgrade.service.d/
    sudo systemctl daemon-reload

To disable later, remove the drop-in and reload:

    sudo rm /etc/systemd/system/apt-daily-upgrade.service.d/skycoin-refresh-before-upgrade.conf
    sudo systemctl daemon-reload
EOF
	#create the update script
	# Update ONLY the skycoin repo: sourcelist= overrides the main sources.list,
	# but apt still scans sources.list.d/ unless sourceparts is also redirected —
	# without it, a single broken third-party repo (e.g. an unsigned armbian
	# configng list) makes `apt update` exit 100 and the whole install fails on
	# someone else's repo. sourceparts=- disables the .d scan; List-Cleanup=0
	# keeps the other repos' cached indexes so skywire-bin's deps still resolve.
	echo "#!/bin/bash
		apt update -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/skycoin.list -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0 &&	apt -qq --yes reinstall skywire-bin && systemctl is-active --quiet install-skywire && systemctl disable install-skywire 2> /dev/null" > ${srcdir}/install-skywire.sh
	#create the update service.
	#Type=oneshot RemainAfterExit=yes so units ordered After=install-skywire
	#(e.g. skybian's skymanager) actually wait for the apt reinstall to
	#FINISH before they start — Type=simple's "active" semantic is "the
	#process has been forked", which lets followers race against the
	#in-flight dpkg replacement of /usr/bin/skywire and the postinst's
	#config-file generation.
	echo "[Unit]
	Description=install skywire service
	After=network-online.target
	Wants=network-online.target

	[Service]
	Type=oneshot
	RemainAfterExit=yes
	ExecStart=/bin/install-skywire

	[Install]
	WantedBy=multi-user.target
	" > ${srcdir}/install-skywire.service

	#skywire-chrootconfig - extended to cover skybian.deb's old role.
	#INSTALLFIRSTBOOT=1 enables install-skywire (first-boot apt reinstall).
	#CHROOTCONFIG=1 additionally enables skymanager (first-boot static-IP
	#claim / hypervisor election, replaces the autopeer behavior that used
	#to be set up by skybian-chrootconfig).
	cat > ${srcdir}/skywire-chrootconfig.sh <<'EOF'
#!/bin/bash
##/usr/bin/skywire-chrootconfig
#called by the postinstall script of the skyrepo .deb package
#meant to run when the skyrepo package is installed in chroot

if [[ $INSTALLFIRSTBOOT == "1" ]] ; then
	if [[ -f /etc/systemd/system/install-skywire.service ]] ; then
		systemctl enable install-skywire.service
	fi
fi

# Skybian-style autoconfig: enable skymanager.service so first boot
# performs the static-IP claim / hypervisor election. CHROOTCONFIG=1
# is set by skybian/skyraspbian IMGBUILDs on the autopeer variants.
if [[ $CHROOTCONFIG == "1" || $CHROOTCONFIG == "true" ]] ; then
	if [[ -f /etc/systemd/system/skymanager.service ]] ; then
		systemctl enable skymanager.service
		systemctl enable NetworkManager-wait-online 2>/dev/null || true
		systemctl enable systemd-networkd 2>/dev/null || true
		systemctl enable systemd-networkd-wait-online 2>/dev/null || true
	fi
fi
EOF

	#create the postinstall script
	echo '#!/bin/bash
	#skyrepo post install script ; executed by dpkg upon package installation or updates
	/usr/bin/skywire-chrootconfig

# Same-day release pickup: activate the apt-daily-upgrade list-refresh drop-in,
# but ONLY where the operator opted into skycoin unattended-upgrades (the 52-
# file is present). apt-daily.timer (list refresh) and apt-daily-upgrade.timer
# (install) are independent timers; when the refresh fires after the upgrade on a
# given day a freshly-published release is missed for a full cycle. The
# ExecStartPre drop-in refreshes the lists right before each upgrade so a new
# release installs same-day. This propagates network-wide through the skyrepo
# auto-upgrade itself, respects the opt-in model (boards that never enabled
# skycoin unattended-upgrades are left untouched, with the drop-in only in
# examples/), is idempotent, and only reloads systemd when the file changes.
_uu=/etc/apt/apt.conf.d/52unattended-upgrades-skycoin
_src=/usr/share/doc/skyrepo/examples/skycoin-refresh-before-upgrade.conf
_ddir=/etc/systemd/system/apt-daily-upgrade.service.d
_ddst="$_ddir/skycoin-refresh-before-upgrade.conf"
if [ -f "$_uu" ] && [ -f "$_src" ]; then
	mkdir -p "$_ddir"
	if ! cmp -s "$_src" "$_ddst" 2>/dev/null; then
		cp "$_src" "$_ddst"
		command -v systemctl >/dev/null 2>&1 && systemctl daemon-reload >/dev/null 2>&1 || true
	fi
fi
exit 0
' > ${srcdir}/postinst.sh
	#create the DEBIAN/control file
	_msg2 "Creating DEBIAN/control file for ${_pkgarch}"
	echo "Package: ${_pkgname}" > ${srcdir}/${_pkgarch}.control
	echo "Version: ${_pkgver}-${_pkgrel}" >> ${srcdir}/${_pkgarch}.control
	echo "Priority: optional" >> ${srcdir}/${_pkgarch}.control
	echo "Section: web" >> ${srcdir}/${_pkgarch}.control
	echo "Architecture: ${_pkgarch}" >> ${srcdir}/${_pkgarch}.control
	echo "Depends: ${_debdeps}" >> ${srcdir}/${_pkgarch}.control
	# skyrepo now ships the files that used to live in skybian.deb
	# (skymanager + skybian-reset + motd snippets + skyenv defaults).
	# Declare the takeover so dpkg cleanly upgrades a box that still
	# has skybian installed: Replaces lets dpkg overwrite the file
	# from skybian's payload (e.g. /etc/default/armbian-motd),
	# Conflicts blocks both being installed at once, Provides keeps
	# any 'Depends: skybian' from third-party packages satisfied.
	echo "Replaces: skybian" >> ${srcdir}/${_pkgarch}.control
	echo "Conflicts: skybian" >> ${srcdir}/${_pkgarch}.control
	echo "Provides: skybian" >> ${srcdir}/${_pkgarch}.control
	echo "Maintainer: Skycoin" >> ${srcdir}/${_pkgarch}.control
	echo "Description: ${pkgdesc}" >> ${srcdir}/${_pkgarch}.control
	cat ${srcdir}/${_pkgarch}.control
}

package() {
  #set up to create a .deb package with dpkg
  _debpkgdir="${_pkgname}-${pkgver}-${_pkgrel}-${_pkgarch}"
  _pkgdir="${pkgdir}/${_debpkgdir}"
  #########################################################################
  #package normally here using ${_pkgdir} instead of ${pkgdir}
  _msg2 "Creating dirs"
  mkdir -p ${_pkgdir}/etc/apt/sources.list.d/
  mkdir -p ${_pkgdir}/etc/apt/trusted.gpg.d/
  mkdir -p ${_pkgdir}/usr/bin/
	mkdir -p ${_pkgdir}/etc/systemd/system/
	mkdir -p ${_pkgdir}/etc/profile.d/
	mkdir -p ${_pkgdir}/etc/default/
	mkdir -p ${_pkgdir}/etc/update-motd.d/
	_msg2 "Installing install-skywire.sh skywire installation script"
	install -Dm755 ${srcdir}/install-skywire.sh ${_pkgdir}/usr/bin/install-skywire
	_msg2 "Installing install-skywire.service service for install-skywire.sh"
	install -Dm644 ${srcdir}/install-skywire.service ${_pkgdir}/etc/systemd/system/install-skywire.service
  _msg2 "Installing skywire-chrootconfig" #called by postinstall
  install -Dm755 ${srcdir}/skywire-chrootconfig.sh ${_pkgdir}/usr/bin/skywire-chrootconfig
  _msg2 "Installing apt repository configuration to:\n    /etc/apt/sources.list.d/skycoin.list"
  install -Dm644 ${srcdir}/skycoin.list ${_pkgdir}/etc/apt/sources.list.d/skycoin.list
  _msg2 "Installing apt repository signing key to:\n    /etc/apt/trusted.gpg.d/skycoin.gpg"
  install -Dm644 ${srcdir}/skycoin.gpg ${_pkgdir}/etc/apt/trusted.gpg.d/skycoin.gpg
  _msg2 "Installing unattended-upgrades example (not activated by default) to:\n    /usr/share/doc/skyrepo/examples/52unattended-upgrades-skycoin"
  install -Dm644 ${srcdir}/52unattended-upgrades-skycoin ${_pkgdir}/usr/share/doc/skyrepo/examples/52unattended-upgrades-skycoin
  install -Dm644 ${srcdir}/99skycoin-periodic ${_pkgdir}/usr/share/doc/skyrepo/examples/99skycoin-periodic
  install -Dm644 ${srcdir}/skycoin-refresh-before-upgrade.conf ${_pkgdir}/usr/share/doc/skyrepo/examples/skycoin-refresh-before-upgrade.conf
  install -Dm644 ${srcdir}/EXAMPLES.README ${_pkgdir}/usr/share/doc/skyrepo/examples/README

  ##### Skybian autoconfig payload (formerly shipped in skybian.deb) #####
  _msg2 "Installing skymanager (static-IP claim / hypervisor election on first boot)"
  install -Dm755 ${startdir}/script/skymanager.sh ${_pkgdir}/usr/bin/skymanager
  install -Dm644 ${startdir}/script/skymanager.service ${_pkgdir}/etc/systemd/system/skymanager.service
  _msg2 "Installing skybian-reset (revert skymanager + skywire config for re-running first-boot)"
  install -Dm755 ${startdir}/script/skybian-reset.sh ${_pkgdir}/usr/bin/skybian-reset
  _msg2 "Installing skyenv (default skywire env vars)"
  install -Dm755 ${startdir}/script/skyenv.sh ${_pkgdir}/etc/profile.d/skyenv.sh
  _msg2 "Installing armbian-motd defaults + 10-skybian-header / 10-skyraspbian-header"
  install -Dm644 ${startdir}/static/armbian-motd ${_pkgdir}/etc/default/armbian-motd
  install -Dm755 ${startdir}/static/10-skybian-header ${_pkgdir}/etc/update-motd.d/10-skybian-header
  install -Dm755 ${startdir}/static/10-skyraspbian-header ${_pkgdir}/etc/update-motd.d/10-skyraspbian-header
  #########################################################################
  _msg2 'Installing control file and postinst script'
  install -Dm755 ${srcdir}/${_pkgarch}.control ${_pkgdir}/DEBIAN/control
  install -Dm755 ${srcdir}/postinst.sh ${_pkgdir}/DEBIAN/postinst
  _msg2 'Creating the debian package'
  cd $pkgdir
	if command -v tree &> /dev/null ; then
	_msg2 'package tree'
	  tree -a ${_debpkgdir}
	fi
	dpkg-deb --build -z9 ${_debpkgdir}
  mv *.deb ../../
	#clean up manually just in case
	rm -rf ${srcdir}
  #exit so the arch package doesn't get built
  exit
}

_msg2() {
	(( QUIET )) && return
	local mesg=$1; shift
	printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@"
}
