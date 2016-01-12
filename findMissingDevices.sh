#!/bin/bash
#########################################################################################################################################
# Description : This script is an utility to search the missing devices in opennms db
# Author: Sandeep Sridhar (ssandeep@juniper.net) - 15th May 2014.
# Copyright (C) 2013, Juniper Networks, Inc.
# All rights reserved.
#
# File History
# Date                  Version                 Author                        Change Summary
#########################################################################################################################################
# 15-May-2014           0.1                    Sandeep Sridhar               Initial Creation of this script for Advanced TAC
#########################################################################################################################################

export LC_ALL=C
buildDBLogicalDevice=/tmp/LogicalDevice.txt
cacheLogicalDevice=/tmp/cacheLogicalDevice.txt
psqlDBNode=/tmp/psqlnode.txt
cachepsqlDBNode=/tmp/cachepsqlnode.txt
LOGFILE=/tmp/findMissingDevices.log
prevJobStatus=""
pgpassFile=/root/.pgpass
missingDevID=/tmp/mDeviceID.txt
resultsFile=/tmp/missingDevices.txt

doPsqlChanges() {
  mr=`cat /etc/redhat-release | awk '{print $3}' | cut -d "." -f1`
  sr=`cat /etc/redhat-release | awk '{print $3}' | cut -d "." -f2`
  is13Dot3=`echo "$sr" | head -c 1`
  if [ "$mr" -eq "13" ]
  then
    if [ "$is13Dot3" -eq "3" ]
    then
      echo "Create the .pgpass file" >> $LOGFILE
      if [ -f "$pgpassFile" ]
      then
        echo "If you have customized $pgpassFile, please take a backup, remove the file $pgpassFile using the command rm -rf $pgpassFile and run this script again.\n"
        echo ""
      else
        echo "*:*:*:postgres:postgres" > $pgpassFile
        chmod 0600 $pgpassFile
      fi
    fi
  fi
}

flushAndCreate() {

  if [ -f "$LOGFILE" ]
  then
    rm -rf $LOGFILE
    echo "Flushed $LOGFILE" > /dev/null 2>&1
  else
    touch $LOGFILE
    echo "No $LOGFILE to flush" >> $LOGFILE
  fi
 
  if [ -f "$resultsFile" ]
  then
    rm -rf $resultsFile
    echo "Flushed $resultsFile >> $LOGFILE
  else
    echo "No $resultsFile to flush" >> $LOGFILE
  fi 

  if [ -f "$buildDBLogicalDevice" ]
  then
    rm -rf $buildDBLogicalDevice
    echo "Flushed $buildDBLogicalDevice" >> $LOGFILE
  else
    echo "No $buildDBLogicalDevice to flush" >> $LOGFILE
  fi

  if [ -f "$psqlDBNode" ]
  then
    rm -rf $psqlDBNode
    echo "Flushed $psqlDBNode" >> $LOGFILE
  else
    echo "No $psqlDBNode" >> $LOGFILE
  fi

  if [ -f "$cacheLogicalDevice" ]
  then
    rm -rf $cacheLogicalDevice
    echo "Flushed $cacheLogicalDevice" >> $LOGFILE
  else
    echo "No $cacheLogicalDevice" >> $LOGFILE
  fi

  if [ -f "$cachepsqlDBNode" ]
  then
    rm -rf $cachepsqlDBNode
    echo "Flushed $cachepsqlDBNode" >> $LOGFILE
  else
    echo "No $cachepsqlDBNode" >> $LOGFILE
  fi

  if [ -f "$missingDevID" ]
  then
    rm -rf $missingDevID
    echo "Flushed $missingDevID" >> $LOGFILE
  else
    echo "No $missingDevID >> $LOGFILE
  fi

}

fetchLogicalDevice() {

  mysql -u jboss --password=netscreen build_db -e "select id from LogicalDevice;" > $cacheLogicalDevice
  sed '1d' $cacheLogicalDevice > $buildDBLogicalDevice
  sort $buildDBLogicalDevice > /tmp/manipulate && mv -f /tmp/manipulate $buildDBLogicalDevice
}

fetchNode() {


  psql -U postgres --no-password --dbname=opennms -c "select foreignid from node;" > $cachepsqlDBNode
  sed '/^$/d' $cachepsqlDBNode > $psqlDBNode
  numOfRowsOnms=`grep "rows" $psqlDBNode | cut -d " " -f1 | cut -d "(" -f2` 
  echo "Number of rows in opennms table is $numOfRowsOnms" >> $LOGFILE
  sed '$d' $psqlDBNode > /tmp/reallyTmp.txt && mv -f /tmp/reallyTmp.txt $psqlDBNode
  sed '1,2d' $psqlDBNode > /tmp/reallyTmp.txt && mv -f /tmp/reallyTmp.txt $psqlDBNode
  cat $psqlDBNode | grep -v "space" > /tmp/reallyTmp.txt && mv -f /tmp/reallyTmp.txt $psqlDBNode
  sed 's/^[ \t]*//' $psqlDBNode > /tmp/reallyTmp.txt && mv -f /tmp/reallyTmp.txt $psqlDBNode

}

flushPgPass() {

  if [ -f "$pgpassFile" ]
  then
    rm -rf $pgpassFile
    prevJobStatus=$?
    if [ "$prevJobStatus" -eq "0" ]
    then
      echo "Successfully removed $pgpassFile from the root's home directory" >> $LOGFILE
    fi   
  fi

}

compare2Files() {

  if [ -f $psqlDBNode -a -f $buildDBLogicalDevice ]
  then
    diff --ignore-all-space $psqlDBNode $buildDBLogicalDevice | grep ">" > $missingDevID
    cat $missingDevID | awk '{print $2}' > /tmp/manipulate && mv -f /tmp/manipulate $missingDevID
    sed '/^$/d' $missingDevID  > /tmp/manipulate && mv -f /tmp/manipulate $missingDevID 
    nol=`cat $missingDevID | wc -l`
    if [ "$nol" -eq "0" ]
    then
      echo "No differences between Space Platform and Opennms" > $resultsFile
    else
      echo "Number of devices missing in Opennms = $nol " >> $resultsFile       
      devids=`cat $missingDevID`
      for i in $devids
      do
        mysql -u jboss --password=netscreen build_db -e "select connStatus,name,INET_NTOA(ip) from DeviceConnectionManagement a,LogicalDevice b,DeviceConnectionStatus c where b.id=a.device_id_id and c.device_id_id=a.device_id_id and b.id = "$i"\G ;" >> $resultsFile
      done
    fi
  echo "Please review the file $resultsFile to know the device name, ip and connection status of the devices that are missing in opennms."
  echo "" 
  fi
}

# Main program starts here.

flushAndCreate
doPsqlChanges
fetchLogicalDevice
fetchNode
flushPgPass
compare2Files
