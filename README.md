#### Skycoin APT repository

[deb.theskywirenetwork.net](https://deb.theskywirenetwork.net)

[deb.skywire.skycoin.com](https://deb.skywire.skycoin.com)

[deb.skywire.dev](https://deb.skywire.dev)

Skywire installation via apt.

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

If you have issues, we are happy to assist on telegram [@skywire](https://t.me/skywire)

[github.com/skycoin/apt-repo](https://github.com/skycoin/apt-repo)
