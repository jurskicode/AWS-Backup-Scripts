#!/bin/bash
#Created by Piotr Jurski
#JURSKI NYC - www.jurskinyc.com
#LICENSE Apache License 2.0
#
#READ ME FIRST!
#Do not update with Notepad++ use 'vi' on Putty
#IF ERROR OCCURS when running: (bash: ./backup.sh: /bin/bash^M: bad interpreter: No such file or directory) 
#USE "sed -i -e 's/\r$//' ec2_prod_snapshot_backup.sh" command

#Flat Server Info (MODIFY SETTINGS HERE)
prod_instance_id=""
prod_volume_01=""
prod_volume_02=""
prod_region=''

#Date
current_date=$(TZ=":America/New_York" date +%Y-%m-%d-%I-%M-%S-%p)
LOG=backup_prod_snapshot.log

#Configurations
prod_snapshot_name="PROD_SNAPSHOT_${current_date}"
prod_snapshot_description="PROD_SERVER_SNAPSHOT"

#Tags
prod_tag_snapshot_name="Key=Name,Value=PROD_Snapshot_Backup"
prod_tag_date="Key=Date,Value=${current_date}"

#==========================
#AWS EC2 BACKUP PROCESS
#==========================

if ! [ -f ~/.aws/credentials ]
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Backup cannot be created because aws authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${LOG}
else
	#Create Flat Server Snapshot
	echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Starting the Snapshot creation ..." | tee --append /backup/backup_logs/${LOG}
	
	snapshot_id=$(aws ec2 create-snapshot --region ${prod_region} --description ${prod_snapshot_description} --volume-id ${prod_volume_01} ${prod_volume_02} --output text --query SnapshotId 2>&1)
	
	snapshot_progress=$(aws ec2 describe-snapshots --region ${prod_region} --snapshot-ids ${snapshot_id} --query "Snapshots[*].Progress" --output text)

	while [ ${snapshot_progress} != "100%" ]
	do
		sleep 15
		echo "Creating Snapshot ID: ${snapshot_id}. Progress: ${snapshot_progress}"
		snapshot_progress=$(aws ec2 describe-snapshots --region ${prod_region} --snapshot-ids ${snapshot_id} --query "Snapshots[*].Progress" --output text)
	done
	
	aws ec2 wait snapshot-completed --region ${prod_region} --snapshot-ids "${snapshot_id}"
	
	if [ "$?" -eq 0 ]
	then
		#Tag the Snapshot
		aws ec2 create-tags --region ${prod_region} --resources ${snapshot_id} --tags ${prod_tag_snapshot_name} ${prod_tag_date}
	fi
	

	#Confirmation to the User
	echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Snapshot id: "${snapshot_id}" was created." | tee --append /backup/backup_logs/${LOG}
fi




