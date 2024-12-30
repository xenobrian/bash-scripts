#!/bin/bash
## This is a script to cure myself from whatever bullshit that Canonical makes for Ubuntu ##
for action in remove purge autoremove; do
    apt $action -y systemd-networkd-wait-online.service unattended-upgrades
done

yes | unminimize