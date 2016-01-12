#!/bin/bash
#########################################################################################################################################
# Description : This script acts as a wrapper calling the core script whenever needed.
# Author: Sandeep Sridhar (ssandeep@juniper.net) - 10th May 2011.
# Copyright (C) 2011, Juniper Networks, Inc.
# All rights reserved.
#
# File History
# Date                  Version                 Author                  Change Summary
#########################################################################################################################################
# 12-May-2011           0.1                     Sandeep S               Initial Creation of this script for the PR 592133 (Customer: BT)
#########################################################################################################################################
HA_STATUS_SCRIPT=/usr/netscreen/HaSvr/utils/haStatus
HASVR_CFG=/usr/netscreen/HaSvr/var/haSvr.cfg
PRIMARY_MEMBER_IP=`cat $HASVR_CFG | grep "highAvail.primaryServerIp" | awk '{print $2}'`
CORE_SCRIPT=/usr/netscreen/GuiSvr/utils/592133_Core.sh

invokeCoreScript()
{
	echo "Loop started"
        while true
        do
          whichIsRunning=`$HA_STATUS_SCRIPT | grep "running" | awk '{print $1}'`
          if [ "$whichIsRunning" != "$PRIMARY_MEMBER_IP" ]
          then
            $CORE_SCRIPT 
          else
            killpid1=`ps -ef | grep "592133_Core.sh" | grep -v "grep" | awk '{print $2}'`
            killpid2=`ps -ef | grep "ConfigFileVersions" | grep -v "grep" | awk '{print $2}'`
            if [ ! -z "$killpid1" ]
            then
               kill -9 "$killpid1"
            fi
            if [ ! -z "$killpid2" ]
            then
              kill -9 "$killpid2"
            fi
          fi
        done                        
}
############################################################################################################################################
#                                              Main Program Starts here                                                                    #
############################################################################################################################################
invokeCoreScript
