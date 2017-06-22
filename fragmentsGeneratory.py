#!/usr/bin/python
 
from scapy.all import *
dip="10.204.75.3"
payload="A"*496+"B"*500
#packet=IP(dst=dip,id=12345)/UDP(sport=1500,dport=1501)/payload
packet=IP(dst=dip,id=2402)/ICMP()/payload
frags=fragment(packet, fragsize=150)
 
counter=1
for fragment in frags:
        print "Packet no#"+str(counter)
        print "==============================================="
        if counter == 2:
                counter+=1
                continue
        else:
                fragment.show()
                counter+=1
                send(fragment)
send(frags[1])
