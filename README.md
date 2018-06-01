# ACME-DNS-NC
Simple helper script for various [Let's Encrypt][1] clients.
Developed for [GetSSL][2] and [ACME.sh][3], tested at Debian and Ubuntu.

## Initial setup
Download or clone the archive and extract it to a new folder.

Copy the example config file `config/.nc-ccp.ini` to `~/.nc-ccp.ini` and insert
your API credentials. Don't forget to check file permissions! (recommended: 0600)

Run it for the first time:

```bash
# Add the TXT record _acme-challenge.example.com with value "test":
./scripts/acme-dns-nc "example.com" "test"

# Check your nameserver: (wait some time)
dig TXT "_acme-challenge.example.com" +short

# Delete the TXT record _acme-challenge.example.com:
./scripts/acme-dns-nc --del "example.com"
```

Take a look at the wiki for more examples.

## Bugs? Feedback?
Open a new issue or drop me a line at cs@fnx.li! :-)

Important: This project is **not** affiliated with netcup GmbH!

## Important links...
* [Bugtracker](https://github.com/froonix/acme-dns-nc/issues)
* [Wiki pages](https://github.com/froonix/acme-dns-nc/wiki)
* [netcup Domains (DE)](https://www.netcup.de/bestellen/domainangebote.php?ref=13994)
* [netcup Domains (EN)](https://www.netcup.eu/bestellen/domainangebote.php?ref=13994)
* [netcup CCP-DNS-API](https://ccp.netcup.net/run/webservice/servers/endpoint.php)
* [Let's Encrypt](https://letsencrypt.org/)

[1]: https://letsencrypt.org/docs/client-options/
[2]: https://github.com/srvrco/getssl
[3]: https://github.com/Neilpang/acme.sh
