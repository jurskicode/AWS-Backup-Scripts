#!/bin/bash
#Created by Piotr Jurski
#JURSKI NYC - www.jurskinyc.com
#LICENSE Apache License 2.0
#
#READ ME FIRST!
#Do not update with Notepad++ use 'vi' on Putty
#IF ERROR OCCURS when running: (bash: ./backup.sh: /bin/bash^M: bad interpreter: No such file or directory) 
#USE "sed -i -e 's/\r$//' rds_prod_snapshot_backup.sh" command

#RDS Info (MODIFY SETTINGS HERE)
rds_instance_id=""
rds_region=''

#Date
current_date=$(TZ=":America/New_York" date +%Y-%m-%d-%I-%M%p)
LOG=backup_rds_prod_snapshot.log

if ! [ -f ~/.aws/credentials ]
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Backup cannot be created because aws authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${LOG}
else
	#Imports from RDS Metadata
	rds_db_status=$(aws rds describe-db-instances --db-instance-identifier ${rds_instance_id} --output text --query DBInstances[*].DBInstanceStatus 2>&1)
	#echo ${rds_db_status}
	
	if [ "$?" -eq 0 ]
	then
		#Configurations
		rds_snapshot_name="rds-prod-snapshot-${current_date}"

		#Tags
		rds_tag_snapshot_name="Key=Name,Value=RDS_PROD_Snapshot_Backup"
		rds_tag_date="Key=Date,Value=${current_date}"

		#==========================
		#AWS RDS BACKUP PROCESS
		#==========================

		#Check if RDS status is available
		if [ ${rds_db_status} == "available" ]
		then
			#Create DB Snapshot
			rds_db_snapshot_id=$(aws rds create-db-snapshot --db-snapshot-identifier ${rds_snapshot_name} --db-instance-identifier ${rds_instance_id} --tags ${rds_tag_snapshot_name} ${rds_tag_date} --output text --query DBSnapshot.DBSnapshotIdentifier 2>&1)
			
			if [ "$?" -eq 0 ]
			then
				echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--RDS Snapshot ID: "${rds_db_snapshot_id}" was created." | tee --append /backup/backup_logs/${LOG}
			else
				echo echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--RDS Snapshot was not created." | tee --append /backup/backup_logs/${LOG}
			fi
		else
			#Display message to user if MySQL is not available
			echo "WARNING: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS RDS Database is currently not in \"Available\" state. Please try again later."
		fi
	else
		echo echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Unable to gather information from AWS." | tee --append /backup/backup_logs/${LOG}
	fi
fi



