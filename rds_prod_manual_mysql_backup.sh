#!/bin/bash
#Created by Piotr Jurski
#JURSKI NYC - www.jurskinyc.com
#LICENSE Apache License 2.0
#
#READ ME FIRST!
#Do not update with Notepad++ use 'vi' on Putty
#IF ERROR OCCURS when running: (bash: ./backup.sh: /bin/bash^M: bad interpreter: No such file or directory) 
#USE "sed -i -e 's/\r$//' ec2_prod_manual_mysql_backup.sh" command

#NEED A .CNF CONFIG FILE TO STORE MYSQL PASSWORD. IT POINTS TO /backup/backup_config/.prod.cnf 
#THE CNF FILE NEEDS TO BE ONLY READ PERMSSION TO USER AND CHOWN AS ROOT OTHERWISE WILL NOT WORK

#Date
current_date=$(TZ=":America/New_York" date +%Y%m%d-%I%M%p)

#(MODIFY SETTINGS HERE)
#RDS
rds_instance_id=""
rds_region=''
#MySQL
DBSERVER=''
DATABASE=TYPEDATABASENAMEHERE
USER=TYPEUSERNAME
PORT=3306
#Files
FILE=${current_date}_prod_backup.sql
LOG=backup_prod_mysql.log
#AWS S3
AWSBucket=TYPEFIRSTBUCKETNAME
AWSBucketWest=TYPESECONDBUCKETNAME

#==========================
#AWS RDS BACKUP PROCESS
#==========================

#Check if AWS Configure is set up
if ! [ -f ~/.aws/credentials ]
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Backup cannot be created because aws authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${LOG}
else
	echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Starting the Manual SQL Backup creation ..." | tee --append /backup/backup_logs/${LOG}
	
	#Check RDS Status
	rds_db_status=$(aws rds describe-db-instances --region ${rds_region} --db-instance-identifier ${rds_instance_id} --output text --query DBInstances[*].DBInstanceStatus 2>&1)
	
	while [ ${rds_db_status} != "available" ]
	do
		sleep 15
		echo "Waiting for RDS Available Status. Current Status: ${rds_db_status}"
		rds_db_status=$(aws rds describe-db-instances --region ${rds_region} --db-instance-identifier ${rds_instance_id} --output text --query DBInstances[*].DBInstanceStatus 2>&1)
	done
	
	echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Current RDS status before mysqldump: ${rds_db_status}" | tee --append /backup/backup_logs/${LOG}

	#Verify that RDS status is "Available"
	if [ "${rds_db_status}" == "available" ]
	then
		#Create MySQL Dump of the database
		mysqldump --defaults-file=/backup/backup_config/.prod.cnf -h ${DBSERVER} -u ${USER} --port=${PORT} --max_allowed_packet=1024M --single-transaction --routines --triggers --databases ${DATABASE} > /backup/sql_backup/production/${FILE}
		
		#Verify if mysqldump communicated successfully to the server
		if [ "$?" -eq 0 ]
		then
			#Inform of success of communication to the shell and log
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--mysqldump has communicated to the server." | tee --append /backup/backup_logs/${LOG}
			
			#Check if backup file exists
			if [ -f /backup/sql_backup/production/${FILE} ]
			then
				# Compress the SQL backup file using GZIP
				gzip -f /backup/sql_backup/production/${FILE}
				
				#Confirmation set into logs
				echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Backup has been created. File: ${FILE}.gz" | tee --append /backup/backup_logs/${LOG}
			else
				echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Backup file of database was not created. Please verify rights to create file in the directory /backup/sql_backup." | tee --append /backup/backup_logs/${LOG}
			fi
		else
			echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Backup of database was not created. Please verify the MySQL database and login information." | tee --append /backup/backup_logs/${LOG}
		fi

	else
		#Display message into the log if MySQL is not available
		echo "WARNING: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--MySQL database is currently not in \"Available\" state. Please try again later. Backup was not performed." | tee --append /backup/backup_logs/${LOG}
	fi

	#==========================
	#UPLOAD BACKUP TO AWS S3
	#==========================
	if [ -f /backup/sql_backup/production/${FILE}.gz ]
	then
		#Upload the SQL Backup to S3
		eTag=$(aws s3api put-object --acl private --bucket ${AWSBucket} --key sql_backup/${FILE}.gz --body /backup/sql_backup/production/${FILE}.gz --server-side-encryption AES256 --output text --query ETag 2>&1)
		if [ "$?" -eq 0 ]
		then	
			#Upload the log
			eTagLog=$(aws s3api put-object --acl private --bucket ${AWSBucket} --key log_backup/${LOG} --body /backup/backup_logs/${LOG} --server-side-encryption AES256 --output text --query ETag 2>&1)
			
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Backup has been uploaded to the AWS bucket: ${AWSBucket}. The SQL Backup eTag # is: "${eTag}". The Log eTag # is "${eTagLog}"." | tee --append /backup/backup_logs/${LOG}
			
		else
			echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Backup has not been uploaded to the AWS bucket: ${AWSBucket}. Please verify the AWS S3 bucket or check authantication to S3 by running \"aws configure\"" | tee --append /backup/backup_logs/${LOG}
		fi
	fi
	
	if [ -f /backup/sql_backup/production/${FILE}.gz ]
	then
		#Upload the SQL Backup to S3 in the West Region
		eTag=$(aws s3api put-object --acl private --bucket ${AWSBucketWest} --key sql_backup/${FILE}.gz --body /backup/sql_backup/production/${FILE}.gz --server-side-encryption AES256 --output text --query ETag 2>&1)
		if [ "$?" -eq 0 ]
		then	
			#Upload the log
			eTagLog=$(aws s3api put-object --acl private --bucket ${AWSBucketWest} --key log_backup/${LOG} --body /backup/backup_logs/${LOG} --server-side-encryption AES256 --output text --query ETag 2>&1)
			
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Backup has been uploaded to the AWS bucket: ${AWSBucketWest}. The SQL Backup eTag # is: "${eTag}". The Log eTag # is "${eTagLog}"." | tee --append /backup/backup_logs/${LOG}
			
		else
			echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Backup has not been uploaded to the AWS bucket: ${AWSBucketWest}. Please verify the AWS S3 bucket or check authantication to S3 by running \"aws configure\"" | tee --append /backup/backup_logs/${LOG}
		fi
	fi
fi


	



