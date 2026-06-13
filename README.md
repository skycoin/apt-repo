#### Skycoin APT repository

[deb.theskywirenetwork.net](https://deb.theskywirenetwork.net)

[deb.skywire.skycoin.com](https://deb.skywire.skycoin.com)

[deb.skywire.dev](https://deb.skywire.dev)

Skywire installation via apt.

#### Install

Select a mirror to install the apt repo configuration package from:
```
curl -Lo skyrepo.deb https://deb.theskywirenetwork.net/skyrepo.deb && sudo dpkg -i skyrepo.deb && rm skyrepo.deb && sudo install-skywire || sudo apt install skywire-bin
```

Alternate mirror (github hosted):
```
curl -Lo skyrepo.deb https://deb.skywire.skycoin.com/skyrepo.deb && sudo dpkg -i skyrepo.deb && rm skyrepo.deb && sudo install-skywire || sudo apt install skywire-bin
```

Alternate mirror:
```
curl -Lo skyrepo.deb https://deb.skywire.dev/skyrepo.deb && sudo dpkg -i skyrepo.deb && rm skyrepo.deb && sudo install-skywire || sudo apt install skywire-bin
```

if you encounter issues with the above step which resulted in skywire not being installed, at that point try
```
sudo apt install skywire-bin
```

read the full package installation and configuration documentation in the [skywire package installation guide](https://github.com/skycoin/skywire/wiki/Skywire-Package-Installation)

#### Installing or upgrading from inside a dmsgpty session

The default install command (above) runs `install-skywire` / `apt install
skywire-bin` as a foreground process attached to your shell session. The
package's postinst regenerates the autoconfig and **restarts the skywire
service** at the end. When the install is happening over `skywire cli dmsg pty
exec` (i.e. you connected to the box via the visor's PTY rather than ssh),
that service restart kills the dmsgpty session — and your shell, the apt
process, and dpkg get a SIGHUP mid-postinst. The package is left
half-configured.

Two workarounds, both shipped by the package set:

**Option A: run the install under `install-skywire.service`** — the systemd
unit is decoupled from your pty session so the service restart can't kill it:

```
curl -Lo skyrepo.deb https://deb.theskywirenetwork.net/skyrepo.deb \
  && sudo dpkg -i skyrepo.deb && rm skyrepo.deb \
  && sudo systemctl start install-skywire.service
```

Trade-off: you lose live progress output (the install runs in the background;
check `journalctl -u install-skywire`).

**Option B: `NOAUTOCONFIG=true` to suppress the postinst restart** — keeps
foreground progress visible; the service isn't touched, so the pty stays
alive. Then trigger autoconfig out-of-band from a NEW connection (which can
be the same dmsgpty target — by that point the existing session has already
exited):

```
curl -Lo skyrepo.deb https://deb.theskywirenetwork.net/skyrepo.deb \
  && sudo dpkg -i skyrepo.deb && rm skyrepo.deb \
  && NOAUTOCONFIG=true sudo apt install skywire-bin
# then, from a fresh session (ssh, or a second pty exec):
sudo systemctl start skywire-autoconfig.service
```

`NOAUTOCONFIG=true` only suppresses the in-line autoconfig+restart; the
package contents (binary, units, configs) are installed normally. The
`skywire-autoconfig.service` is shipped by `skywire-bin` and runs the same
config regen + service-restart that the postinst would have, but from outside
your interactive session.

If you're installing over ssh (default) you don't need either workaround —
the standard command works as-is. This section only matters when the
install/upgrade is running over a dmsgpty connection.

#### Optional: enable unattended-upgrades for the Skycoin repo

The `skyrepo` package ships an example drop-in for `unattended-upgrades(8)` at
`/usr/share/doc/skyrepo/examples/52unattended-upgrades-skycoin`. It is NOT
activated on install — the package only adds the apt source. To opt in so that
`skywire-bin` and related Skycoin packages upgrade automatically on the system's
regular `apt-daily-upgrade.timer` schedule:

```
sudo cp /usr/share/doc/skyrepo/examples/52unattended-upgrades-skycoin \
        /etc/apt/apt.conf.d/
```

Confirm the origin metadata matches the file's `Origins-Pattern`:

```
apt-cache policy | grep -A1 skycoin
```

To disable later, remove the file:

```
sudo rm /etc/apt/apt.conf.d/52unattended-upgrades-skycoin
```

#### Interactive install-command generator

Each mirror above serves a browser-based form at `/generator/` that builds the install command (and a downloadable `/etc/skywire.conf` and `skywire.json`) from your chosen autoconfig flags:

- [deb.theskywirenetwork.net/generator/](https://deb.theskywirenetwork.net/generator/)
- [deb.skywire.skycoin.com/generator/](https://deb.skywire.skycoin.com/generator/)
- [deb.skywire.dev/generator/](https://deb.skywire.dev/generator/)

The form's flag set tracks `pkg/skywireconfig/autoconfigcmd` at the skywire version this repo was last rebuilt against.

If you have issues, we are happy to assist on telegram [@skywire](https://t.me/skywire)

[github.com/skycoin/apt-repo](https://github.com/skycoin/apt-repo)
