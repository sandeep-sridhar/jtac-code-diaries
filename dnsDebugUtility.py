#
# Copyright (c) 2016 Sandeep Sridhar - ssandeep@juniper.net
# Advanced TAC, OpenContrail - Juniper Networks Inc
# All rights reserved.
#
import sys
import copy
import xmltodict
import urllib2
import argparse
import sys
import random
from contrail_sandeshlibs import *
from novaclient import client

hostname=["10.224.19.5","10.224.19.9","10.224.19.13"]
passiveDNS=''
activeDNS=[]
fullListOfHypervisor=[]
recordNameList=[]
domainName=''

def main():
    listOfActiveDNS = whoHasActiveDNS()
    print "\n==================================================="
    print "List of Active DNS:",listOfActiveDNS
    print "==================================================="
    dnsIP = random.choice(listOfActiveDNS)

    # hypervisorList() is a function that uses nova api to retrieve the list of hypervisors.
    compNodeList = hypervisorList()

    # registeredComputes() is a function that uses Snh_ShowAgentList introspect to see who is registered for the DNS service.
    regComputes = registeredComputes(dnsIP)

    # Compare the previously calculated lists and check whether every compute is registered with the dns-server.
    compareHypListAndCompute(compNodeList,regComputes)

    # Juniper IT has several Contrail Clusters. The vDNS names are dynamic and hence they prefer the user keying in the vDNS name.
    domainName = readDomain()

    deltaBnDNS = compareDNSRecords(listOfActiveDNS,domainName)

    if deltaBnDNS == 0:
        print "\nDNS records match between the two active Contrail vDNS."
    else:
        print "\nDNS records don't match between the two active Contaril vDNS. Please re-check the domain name you entered."
        print "If you are sure the domain name entered is correct, something is wrong and might require restart of some contrail" 
        print "services like named,dns etc.."
        print "Please seek help by opening a JTAC Case.\n"

def whoHasActiveDNS():
    path='Snh_ShowAgentList?'
    port='8092'
    for ip in hostname:
        introspect  = GetContrailSandesh(hostname=ip,port=port)
        res = introspect.get_path_sandesh_to_dict(path)
        if res['DnsAgentListResponse']['agent'] == '':
            passiveDNS = ip
        else:
            activeDNS.append(ip)
    return activeDNS

def registeredComputes(ipDNS):
    ipAddress = ipDNS
    peerList=[]
    path='Snh_ShowAgentList?'
    port='8092'
    introspect  = GetContrailSandesh(hostname=ipAddress,port=port)
    res = introspect.get_path_sandesh_to_dict(path)
    peers = res['DnsAgentListResponse']['agent']
    for peer in peers:
        peerName = peer['peer']
        peerNameSplit = peerName.split('/')[0]
        peerList.append(peerNameSplit)
    return peerList

def hypervisorList():
    # I tried using BgpNeighborReq? introspect by fishing out only XMPP peers
    # Later realized, it isn't a reliable approach because if a compute node has XMPP failures with the control node,
    # we would miss that in the introspect. Therefore, using nova client APIs
    nt = client.Client(2,"it_automation","c0ntrail123","performance","http://10.224.19.241:5000/v2.0/")
    res = nt.hypervisors.list()
    lenOfList = res.__len__()
    for x in range (0,lenOfList):
        hl = nt.hypervisors.list()[x]
        fullListOfHypervisor.append(hl.hypervisor_hostname)
    return fullListOfHypervisor

def compareHypListAndCompute(rComputes,cNodes):
    delta = set(rComputes) - set(cNodes) | set(cNodes) - set(rComputes)
    if len(delta) == 0:
        print "\nAll Compute Nodes in the Contrail Cluster are registered to the vDNS service.\n"
    else:
        print "\nIt seems like there are some computes that are not registered. Here are the unregistered nodes::\n",delta

def showDnsConfig(ipDNS,dName):
    ipAddress = ipDNS
    dn = dName
    recNameList=[]
    path='Snh_ShowDnsConfig?'
    port='8092'
    introspect = GetContrailSandesh(hostname=ipAddress,port=port)
    res = introspect.get_path_sandesh_to_dict(path)
    vDNSRecords = res['DnsConfigResponse']['virtual_dns']
    numOfDNS = vDNSRecords.__len__()
    for i in range(0,numOfDNS):
        tmp = vDNSRecords[i]
        tmp1 = tmp['records']
        lenOftmp1 = tmp1.__len__()
        for j in range(0,lenOftmp1):
            if (tmp1[j]['rec_type']) in ['A'] and (tmp1[j]['name'].split(':')[1]) == dn:
                recNameList.append(tmp1[j]['rec_name'])
            else:
                continue
    return recNameList

def readDomain():
    print "\nWARNING: The input you are entering below is case-sensitive"
    domainName = raw_input("Please enter the domain for which you would like to compare the DNS Records: ")
    return domainName

def compareDNSRecords(lDNS,dn):
    dnsList = lDNS
    dName = dn
    for idx, ip in enumerate(dnsList):
        records = showDnsConfig(ip,dName)
        if idx == 0:
            recSwap = records
            recSwap.__len__()
    if (recSwap.__len__() != 0) and (records.__len__() != 0) and recSwap.__len__() == records.__len__():
        return 0
    else:
        return 1

if __name__ == "__main__":
    main()
