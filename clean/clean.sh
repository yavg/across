#!/usr/bin/env bash
# Wiki: debian 10 clean
# Usage: bash <(curl -s https://raw.githubusercontent.com/mixool/across/master/clean/clean.sh)



#
apt autoremove
apt clean
apt autoclean

#
dpkg --list | grep "^rc" | cut -d " " -f 3 | xargs dpkg --purge

# logs
rm -rf /var/log/*
