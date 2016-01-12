#!/bin/bash

#########################################################################################################################################
# Description : Shell script to copy auto import config file from primary server to secondary server in case of NSM HA Failover.
# Author: Sandeep Sridhar (ssandeep@juniper.net) - 10th May 2011.
# Copyright (C) 2011, Juniper Networks, Inc.
# All rights reserved.
#
# File History
# Date			Version			Author			Change Summary
#########################################################################################################################################
# 10-May-2011		0.1			Sandeep S		Initial Creation of this script for the PR 592133 (Customer: BT)
# 11-May-2011           0.2                     Sandeep S               Fixed a bug which would put a condition before copying the files
#                                                                       to remote server. 
#########################################################################################################################################

HASVR_CFG=/usr/netscreen/HaSvr/var/haSvr.cfg
LOGFILE=/tmp/592133.log
DATE=`date`
CONFIG_FILE_VERSIONS=/usr/netscreen/GuiSvr/var/ConfigFileVersions
GUI_PIDFILE=/tmp/gpids.pid
DEV_PIDFILE=/tmp/dpids.pid
HA_STATUS_SCRIPT=/usr/netscreen/HaSvr/utils/haStatus
createLogFile()
{
       if [ -f $LOGFILE ]
       then
         echo "Script begins here `date`" >> $LOGFILE
         echo "" >> $LOGFILE
       else
         touch $LOGFILE
         chmod 777 $LOGFILE
       fi
       
       if [ -f $GUI_PIDFILE ]
       then
         chown nsm:nsm $GUI_PIDFILE
       else
         touch $GUI_PIDFILE
       fi

       if [ -f $DEV_PIDFILE ]
       then
         chown nsm:nsm $DEV_PIDFILE
       else
         touch $DEV_PIDFILE
       fi
}

checkIfHA()
{
	if [ -f $HASVR_CFG ]
	then
   	  # use a logic to store the ip addresses of primary member and secondary members.
	  # this is needed for further processing.
   	  PRIMARY_MEMBER_IP=`cat $HASVR_CFG | grep "highAvail.primaryServerIp" | awk '{print $2}'`
	  SECONDARY_MEMBER_IP=`cat $HASVR_CFG | grep "highAvail.secondaryServerIp" | awk '{print $2}'`
	fi

	# If either PRIMARY_MEMBER_IP or SECONDARY_MEMBER_IP is blank. It means, that the member is not in HA mode, just quit gracefully.
        if [[ "$PRIMARY_MEMBER_IP" = "\"\"" || "$SECONDARY_MEMBER_IP" = "\"\"" ]]
        then
          echo "[$DATE]::This server is not in HA Mode. This script is intended to run on a server which is in High Availability Deployment only" >> $LOGFILE
          echo "[$DATE]::" >> $LOGFILE
          exit
        else
          echo "[$DATE]::This server is in High Availability Deployment" >> $LOGFILE
          echo "[$DATE]::" >> $LOGFILE
          echo "[$DATE]::The Primary Server's IP is :$PRIMARY_MEMBER_IP" >> $LOGFILE
          echo "[$DATE]::" >> $LOGFILE
          echo "[$DATE]::The Secondary Server's IP is :$SECONDARY_MEMBER_IP" >> $LOGFILE
        fi
}

archivePID() 
{
	# Let us create a logfile in the name of the PR number and log some data to it. Will help in debugging if script fails.

        if [ -f $LOGFILE ]
        then
          echo "Script begins here:::: `date`" >> $LOGFILE
          echo "" >> $LOGFILE
        else
          touch $LOGFILE
          chmod 777 $LOGFILE
        fi

        # Once the fail over happens, it takes a while for the GuiSvr processes and DevSvr processes to launch and run. I am sleeping idle 
        # for 150 seconds here.zzzzzzzzzz :) 
        sleep 150
        
        # Let us archive the pids of all processes on the primary server. The best way to detect failover is to keep monitoring the pids.
        # If a pid is lost, just blindly assume that the HA Fail Over happens. The other way is to monitor the daemon logs for a failover
        # message. However, this increases the memory cycles on the kernel.

        # Archive the GuiSvr process ids.
        gpids=`/etc/init.d/guiSvr status | cut -d ')' -f1 | awk '{print $3}' | grep -v "is"`
        echo "$gpids" > /tmp/gpids.pid
        echo "[$DATE]::The GuiSvr process ids are: $gpids" >> $LOGFILE
        echo "[$DATE]::" >> $LOGFILE
        
        # Archive the DevSvr process ids.
        dpids=`/etc/init.d/devSvr status | cut -d ')' -f1 | awk '{print $3}' | grep -v "is"`
        echo "$dpids" > /tmp/dpids.pid
        echo "[$DATE]::The DevSvr process ids are: $dpids" >> $LOGFILE
        echo "[$DATE]::" >> $LOGFILE
}

monitorPID()
{
	# Keep monitoring the PIDs in an infinite loop here.
        if [ -f /tmp/dpids.pid ]
        then
          dpids=`cat /tmp/dpids.pid`
        else
          echo "[$DATE]::The script cannot run further due to the unavailability of the DevSvr process ids"
          echo ""
          exit
        fi

        if [ -f /tmp/gpids.pid ]
        then
          gpids=`cat /tmp/gpids.pid`
        else
          echo "[$DATE]::The script cannot run further due to the unavailability of the GuiSvr process ids"
          echo ""
          exit
        fi
        
        while true
        do
           for i in $gpids $dpids
           do
            ps -p $i > /dev/null 2>&1
            rc=`echo $?`
            if [ "$rc" != "0" ]
            then
	      echo "[$DATE]::The PID $i is lost/killed. HA Failover will be triggered from NSM shortly" >> $LOGFILE       
              # Sleep for two minutes allowing the NSM to gracefully sync the folder /var/netscreen/GuiSvr/var/*
              sleep 120          
              copyConfigToActive     
            fi
           done
        done
}

copyConfigToActive() 
{
           for i in `ls $CONFIG_FILE_VERSIONS`
           do
             for j in `ls $CONFIG_FILE_VERSIONS/$i/`
             do
                echo "[$DATE]::Copying $j present in $i to the remote server ($SECONDARY_MEMBER_IP)" >> $LOGFILE 

                # Create directories by that name on the remote server. I am just assuming that the trust has been established between the 
                # HA members in NSM and no password is prompted when we create directory on remote servers. I guess, establishing trust between
                # the HA members is a part of NSM HA operating procedures.
                echo "Changing user to NSM" >> $LOGFILE
                ssh -t nsm@$SECONDARY_MEMBER_IP "mkdir -p $CONFIG_FILE_VERSIONS/$i"
                echo "Changed user to NSM::$USER" >> $LOGFILE
                # To-Do:Copying logic to be coded here.          
                scp $CONFIG_FILE_VERSIONS/$i/$j $SECONDARY_MEMBER_IP:$CONFIG_FILE_VERSIONS/$i/
                # copying to remote server done. why to copy it over and over again by increasing memory cycles on the remote machine.
                rm -rf $CONFIG_FILE_VERSIONS/$i/$j 
             done
           done
}

############################################################################################################################################
#                                              Main Program Starts here                                                                    #
############################################################################################################################################
createLogFile
#archivePID
checkIfHA
#monitorPID
copyConfigToActive
