#### Skycoin APT repository
[deb.skywire.skycoin.com](https://deb.skywire.skycoin.com)

skywire installation via apt

```
sudo dpkg -i $(curl -L https://github.com/skycoin/apt-repo/releases/download/current/skyrepo-$(dpkg --print-architecture).deb -o skyrepo-$(dpkg --print-architecture).deb && echo -e skyrepo-$(dpkg --print-architecture).deb) && sudo rm skyrepo-*.deb && sudo install-skywire || sudo apt install skywire-bin
```

if you encounter issues with the above step which resulted in skywire not being installed, at that point try
```
sudo apt install skywire-bin
```

read the full package installation and configuration documentation in the [skywire package installation guide](https://github.com/skycoin/skywire/wiki/Skywire-Package-Installation)

If you have issues, we are happy to assist on telegram [@skywire](https://t.me/skywire)

[github.com/skycoin/apt-repo](https://github.com/skycoin/apt-repo)
