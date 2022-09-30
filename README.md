#### Skycoin APT repository

skywire installation via apt

```
sudo dpkg -i $(curl https://deb.skywire.skycoin.com/archive/skybian-$(dpkg --print-architecture).deb -o skybian-$(dpkg --print-architecture).deb && echo -e skybian-$(dpkg --print-architecture).deb) && rm skybian-*.deb && install-skywire
```

read the full documentation in the [skywire package installation guide](https://github.com/skycoin/skywire/wiki/Skywire-Package-Installation)
