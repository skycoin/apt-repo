#### Skycoin APT repository
[deb.skywire.skycoin.com](https://deb.skywire.skycoin.com)

skywire installation via apt

```
sudo dpkg -i $(curl -L https://github.com/skycoin/apt-repo/releases/download/current/skybian-$(dpkg --print-architecture).deb -o skybian-$(dpkg --print-architecture).deb && echo -e skybian-$(dpkg --print-architecture).deb) && rm skybian-*.deb && install-skywire
```

read the full documentation in the [skywire package installation guide](https://github.com/skycoin/skywire/wiki/Skywire-Package-Installation)

[github.com/skycoin/apt-repo](https://github.com/skycoin/apt-repo)
