#!/bin/bash

# Author : Arun Sasidhar
# Purpose : MySQL Databse Backup
# Description : Backup All MySQL DBs except Those excluded.
# Last Modified : 17/06/2013

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# MySQL Databse Credentials for Backup
MySQL_USER="root"
MySQL_PASSWORD="password"
MySQL_HOST="localhost"

# Pipe seperated list of DBs to be excluded from the backup.
# Do Not Remove test DB name from exclude list.
EXCLUDE_DBS="test" 

# Directory Location where DB backups are stored.
BACKUP_DIR="/backup/Mysqlbkp"

# Set How many Days Backups To keep in Backup Directory.
MAX_BACKUPS=7 

# Set Time Format
DATE=$(date +"%Y%m%d")
S_DATE=$(date +"%B-%d")

#Admin Email Address to send Backup Status.
ADMIN_EMAIL="admin@example.com"

# Log File
LOG_FILE=/var/log/mysql-backup.log

# =========================================================================

MySQL=`which mysql`
MySQLDUMP=`which mysqldump`
MYSQLADMIN=`which mysqladmin`
DUMP_OPTION="--quick --single-transaction"

# save stdout and stderr to file descriptors 3 and 4, then redirect them to Log File
exec 3>&1 4>&2 >/tmp/.mydb-backup.log 2>&1

# restore stdout and stderr incase of any Kill signal
trap "exec 1>&3 2>&4" SIGHUP SIGINT SIGTERM

echo ""
TIME=$(date +"%Y%m%d_%H:%M:%S")
echo "$TIME -- Info --Starting Mysql database Backup @ $(hostname)..."

TIME=$(date +"%Y%m%d_%H:%M:%S")
echo "$TIME -- Info --Backup Directory is $BACKUP_DIR" 

TIME=$(date +"%Y%m%d_%H:%M:%S")
echo "$TIME -- Info --Backup Retention Time is $MAX_BACKUPS Days" 

# Check MySQL Connectivity.
$MySQL -h$MySQL_HOST -u$MySQL_USER -p$MySQL_PASSWORD -Bse 'show databases' >/dev/null 2>&1
retval=$?
if [ $retval -ne 0 ]; then
        TIME=$(date +"%Y%m%d_%H:%M:%S")
        echo "$TIME -- Error -- Unable to Connect to MySQL Server. Check Connection paramaeters"
        exit 1
fi

# Get all database name
DBS=`$MySQL -h$MySQL_HOST -u$MySQL_USER -p$MySQL_PASSWORD -Bse 'show databases' | grep -vE "$EXCLUDE_DBS"`
if [ -z $DBS ] > /dev/null 2>&1 ; then
  TIME=$(date +"%Y%m%d_%H:%M:%S")
        echo "$TIME -- Error -- No Database to Backup!"
	exit 1
fi

# Check Backup Directory
if [ -d $BACKUP_DIR ]; then
        [ ! -d $BACKUP_DIR/MYSQL_Backup-$S_DATE ] && mkdir $BACKUP_DIR/MYSQL_Backup-$S_DATE
else
        TIME=$(date +"%Y%m%d_%H:%M:%S")
        echo "$TIME -- Error -- Backup Directory Doesn't Exist"
        exit 1
fi

# Start Backup
for db in $DBS
do
        TIME=$(date +"%Y%m%d_%H:%M:%S")
        echo "$TIME -- Info --Starting Backup of $db database..."
        $MYSQLADMIN -h$MySQL_HOST -u$MySQL_USER -p$MySQL_PASSWORD flush-logs
        $MySQLDUMP -h$MySQL_HOST -u$MySQL_USER -p$MySQL_PASSWORD $DUMP_OPTION $db | gzip > $BACKUP_DIR/MYSQL_Backup-$S_DATE/$db.$TIME.sql.gz
	retval=$?
	if [ $retval -ne 0 ]; then
        	TIME=$(date +"%Y%m%d_%H:%M:%S")
	        echo "$TIME -- Error --Failed To Backup $db Database. See the Error above."
	else
		TIME=$(date +"%Y%m%d_%H:%M:%S")
	        echo "$TIME -- Info --Completed Backup of $db database."
	fi

done

# Delete OLD backup
TIME=$(date +"%Y%m%d_%H:%M:%S")
echo "$TIME -- Info --Deleting $MAX_BACKUPS days Old Backups..."
rm -rf `find $BACKUP_DIR -name "MYSQL_Backup*" -mtime +"$MAX_BACKUPS" -print`
retval=$?
if [ $retval -ne 0 ]; then
        TIME=$(date +"%Y%m%d_%H:%M:%S")
        echo "$TIME -- Error --Failed To Delete OLD backups. See the Error above."
else
	TIME=$(date +"%Y%m%d_%H:%M:%S")
	echo "$TIME -- Info --Completed Mysql database Backup @ $(hostname)..."
fi

# Send Backup Status Mail To Admin
cat /tmp/.mydb-backup.log | mail -s "$(date +%F) :: MySQL Backup Has been Completed @ $(hostname)." $ADMIN_EMAIL

# Logging
cat /tmp/.mydb-backup.log >> $LOG_FILE
rm -f /tmp/.mydb-backup.log
exit 0
