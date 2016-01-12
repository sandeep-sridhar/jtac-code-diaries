#!/bin/sh
#########################################################################################################################################
# Description : This script can be used to collect thread dumps on jboss to help dev fix memory/stuck jobs issue.
# Author: Sandeep Sridhar (ssandeep@juniper.net) - 13-Jan-2014
# Copyright (C) 2014, Juniper Networks, Inc.
# All rights reserved.
#
# File History
# Date                  Version                 Author                        Change Summary
#########################################################################################################################################
# 13-Jan-2014           0.1                     Sandeep Sridhar               Initial Creation of this script for Advanced TAC
#########################################################################################################################################

# Modify this variable maxLoop per your requirement. It usually collects thread dumps maxLoop number of times in a span of (maxLoop * 5) intervals.
maxLoop=4
consoleFile=/var/log/jboss/console
dumpFilePath=/tmp
threadDumpCollector()
{
   for i in `seq 1 $maxLoop`
   do
     kill -s QUIT `ps aux | grep jboss | grep -v grep | grep  "Xms" | awk '{print $2}'`
     cp $consoleFile $dumpFilePath/console$i
     sleep 5
   done
}

notifyUser()
{
   for i in `seq 1 $maxLoop`
   do
     if [ -f $dumpFilePath/console$i ]
     then
        echo "Please provide the file $dumpFilePath/console$i to your support engineer."
     fi
   done 
   echo "TIP: Refer KB15585 to reliably and securely FTP files to JTAC."
}

# Main program starts here.
threadDumpCollector
notifyUser

