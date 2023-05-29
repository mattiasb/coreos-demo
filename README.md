# CoreOS Demo #

A simple CoreOS demo showing how to get a Grafana instance running.

## Quick Setup ##

1. Run `make install-dependencies` (only on Fedora right now, sorry).
2. Run `make`
3. Run `make create-vm`
4. Wait (10m or so)
5. Type `Ctrl+]` to release the console
6. Use the IP address printed above the Login entry to create an `/etc/hosts`
   entry like this:
   ```
   192.168.124.<NNN> coreos.lan grafana.lan
   ```
7. Try reaching `coreos.lan` and `grafana.lan` in your browser. You might have
   to explicitly *allow* the `.lan` TLD.
