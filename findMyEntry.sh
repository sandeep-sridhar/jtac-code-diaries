#!/bin/sh
#########################################################################################################################################
# Description : This script is an utility to search the mysql tables where the required string is present.
# Author: Sandeep Sridhar (ssandeep@juniper.net) - 27th July 2013.
# Copyright (C) 2013, Juniper Networks, Inc.
# All rights reserved.
#
# File History
# Date                  Version                 Author                        Change Summary
#########################################################################################################################################
# 27-July-2013           0.1                    Sandeep Sridhar               Initial Creation of this script for Advanced TAC
#########################################################################################################################################
export LC_ALL=C
build_db_table_file=/tmp/build_db_tables.txt
sm_db_table_file=/tmp/sm_db_tables.txt
allRecordsBuildDB=/tmp/allRecordsBuildDB.txt
allRecordsSmDB=/tmp/allRecordsSmDB.txt
entityToBeSearched=$1
summaryOutput=/tmp/summaryOutPutResults.txt
prevJobStatus=""
cacheFile=/tmp/cache.txt
cacheFile1=/tmp/cache1.txt

LOGFILE=/tmp/queryFinder.log

flush() {

  if [ -f "$LOGFILE" ]
  then
    rm -rf $LOGFILE
    echo "Flushed $LOGFILE" > /dev/null 2>&1
  else
    touch $LOGFILE
    echo "No $LOGFILE to flush" >> $LOGFILE
  fi


  if [ -f "$build_db_table_file" ]
  then
    rm -rf $build_db_table_file
    echo "Flushed $build_db_table_file" >> $LOGFILE
  else
    echo "No $build_db_table_file to flush" >> $LOGFILE
  fi

  if [ -f "$sm_db_table_file" ]
  then
    rm -rf $sm_db_table_file
    echo "Flushed $sm_db_table_file" >> $LOGFILE
  else
    echo "No $sm_db_table_file to flush" >> $LOGFILE
  fi

  
  if [ -f "$allRecordsBuildDB" ]
  then
    rm -rf $allRecordsBuildDB
    echo "Flushed $allRecordsBuildDB" >> $LOGFILE
  else
    echo "No $allRecordsBuildDB to flush" >> $LOGFILE
  fi

  if [ -f "$allRecordsSmDB" ]
  then
    rm -rf $allRecordsSmDB
    echo "Flushed $allRecordsSmDB" >> $LOGFILE
  else
    echo "No $allRecordsSmDB to flush" >> $LOGFILE
  fi
  
  if [ -f $summaryOutput ]
  then
    echo "Flushed $summaryOutput" >> $LOGFILE
    rm -rf $summaryOutput
  else
    echo "No $summaryOutput to flush" >> $LOGFILE
  fi

}

createFileWithTableNamesForBuildDB() {

  mysql -u jboss --password=netscreen build_db -e "show tables;" > $cacheFile
  #mysql -u jboss --password=netscreen sm_db -e "show tables;" >> $cacheFile

  # using sed here to delete line number 1 of the generated file because the entry is a header and not actually a mysql table
  sed '1d' $cacheFile > $build_db_table_file
  if [ -f "$cacheFile" ]
   then
    rm -rf $cacheFile
  fi

}

createFileWithTableNamesForSmDB() {

  mysql -u jboss --password=netscreen sm_db -e "show tables;" > $cacheFile1

  # using sed here to delete line number 1 of the generated file because the entry is a header and not actually a mysql table
  sed '1d' $cacheFile1 > $sm_db_table_file
  if [ -f "$cacheFile1" ]
   then
    rm -rf $cacheFile1
  fi

}

# build a master file here with the output of select * from table_name of all tables in the database
queryFunctionForBuildDB() {
	echo "Searching $entityToBeSearched in all tables from build_db..."
        for line in $(cat "$build_db_table_file");
	do
                # do not append to $allRecordsBuildDB. Re-writing to optimize the search time by not increasing the size of $allRecordsBuildDB
                mysql -u jboss --password=netscreen build_db -e "select * from $line;" > $allRecordsBuildDB
                echo "Reading table => $line => `date`" >> $LOGFILE
                # redirecting it to /dev/null to avoid shitty messages on screen when user runs this script
                grep -i -w $entityToBeSearched $allRecordsBuildDB > /dev/null 2>&1
                prevJobStatus=`echo $?`
                echo "Done reading table => $line => `date`" >> $LOGFILE
                if [ "$prevJobStatus" -eq "0" ]
                then
                 echo "Found in mySql table $line" >> $summaryOutput
                fi           
        done
        if [ -f "$summaryOutput" ]
        then
          echo "Done searching $entityToBeSearched in all tables. Please review the file /tmp/summaryOutPutResults.txt for results."
        else
          echo "Done searching $entityToBeSearched in all tables. No table exists with the entry $entityToBeSearched. Sorry!"
        fi
}

queryFunctionForSmDB() {
        echo "Searching $entityToBeSearched in all tables in sm_db..."
        for line in $(cat "$sm_db_table_file");
        do
                # do not append to $allRecordsBuildDB. Re-writing to optimize the search time by not increasing the size of $allRecordsBuildDB
                mysql -u jboss --password=netscreen sm_db -e "select * from $line;" > $allRecordsSmDB
                echo "Reading table => $line => `date`" >> $LOGFILE
                # redirecting it to /dev/null to avoid shitty messages on screen when user runs this script
                grep -i -w $entityToBeSearched $allRecordsSmDB > /dev/null 2>&1
                prevJobStatus=`echo $?`
                echo "Done reading table => $line => `date`" >> $LOGFILE
                if [ "$prevJobStatus" -eq "0" ]
                then
                 echo "Found in mySql table $line" >> $summaryOutput
                fi
        done
        if [ -f "$summaryOutput" ]
        then
          echo "Done searching $entityToBeSearched in all tables. Please review the file /tmp/summaryOutPutResults.txt for results."
        else
          echo "Done searching $entityToBeSearched in all tables. No table exists with the entry $entityToBeSearched. Sorry!"
        fi
}

flushTheCode() {

    # delete the source code to prevent mis-use/abuse without the author's permission :) - ssandeep
    rm -rf /tmp/findMyEntry.sh

}
# Main Program Starts here
flush
createFileWithTableNamesForBuildDB
createFileWithTableNamesForSmDB
queryFunctionForBuildDB
queryFunctionForSmDB
flushTheCode
