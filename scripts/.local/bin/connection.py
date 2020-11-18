#!/usr/bin/python3

# Requires ifaddr [pip install ifaddr]

import tempfile
import os
from urllib.error import URLError

import ifaddr


# LAN IPs
excluded = []

lan = ""

adapters = ifaddr.get_adapters()
for adapter in adapters:
    ips = adapter.ips
    for ip in ips:
        addr = ""
        if isinstance(ip.ip, str):
            addr = ip.ip
        else:
            # IPv6
            # Only display ipv6 if no v4 available
            if len(ips) == 1:
                addr = ip.ip[0]
        # Exclude ips ending with .1, because they tend to not be dynamic and all link-local addresses
        if (not addr == "") and (not addr[len(addr)-2:] == ".1") and (not addr.startswith("fe80::")) and (addr not in excluded):
        # if (not addr == "") and (addr not in excluded):
            name = {
                "eth0": "\uf6ff",
                "wlan0": "\ufaa8",
                "bnep0": "\uf5ae",
                "docker0": "\uf308",
                "wg0": "\uf83d",
                }.get(adapter.nice_name, adapter.nice_name+" :")
            lan += '  ' + name + " " + addr

if not lan == "":
    text = lan[2:]
    #stext = text.split(":")
    #if len(stext) < 3:
    #    text = stext[1]
else:
    text = "\uf071 Not Connected"

print(" " + text.strip())
