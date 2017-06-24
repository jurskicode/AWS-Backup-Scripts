#!/bin/bash
#Created by Piotr Jurski
#JURSKI NYC - www.jurskinyc.com
#LICENSE Apache License 2.0
#
#READ ME FIRST!
#Do not update with Notepad++ use 'vi' on Putty
#IF ERROR OCCURS when running: (bash: ./backup.sh: /bin/bash^M: bad interpreter: No such file or directory) 
#USE "sed -i -e 's/\r$//' ec2_prod_cleanup_backup.sh" command

source /etc/profile
 
#AWS CONFIGURATIONS 
region=''
westregion=''
tagName=Name
tagValue=PROD_Snapshot_Backup
tagStageValue=Snapshot_Backup
tagDate="Date"
amiTagName=Name
amiTagValue=PROD_AMI_Backup
amiStageTagValue=AMI_Backup
amiTagDate="Date"
rdsTagName=Name
rdsTagValue=RDS_PROD_Snapshot_Backup
rdsStageTagValue=RDS_Snapshot_Backup
rdsTagDate="Date"
#ownerID=UNCOMMENT AND TYPE IN AWS ACCOUNT ID
#S3BUCKET=UNCOMMENT AND TYPE IN FIRST BUCKET FROM S3
#S3BUCKETWEST=UNCOMMENT AND TYPE IN SECOND BUCKET FROM S3


#VARIABLES
DATESTAMP=`date +%Y%m%d-%H%M%S`

#LOCATIONS
SNAPLOCATION=/backup/aws/ec2_snapshots/
AMILOCATION=/backup/aws/ami/
RDSLOCATION=/backup/aws/rds_snapshots/
SQLLOCATION=/backup/local/sql/
WWWLOCATION=/backup/local/www/
SQLBACKUP=/backup/sql_backup/production/
STAGESQLBACKUP=/backup/sql_backup/stage/
WWWBACKUP=/backup/www_backup/production/
STAGEWWWBACKUP=/backup/www_backup/stage/
S3SQLBACKUP=sql_backup/
S3WWWBACKUP=www_backup/
JQLOCATION=/backup/scripts/production
STAGEJQLOCATION=/backup/scripts/stage

#JSON AND DATA PRODUCTION
SNAPANDDATE="/backup/aws/ec2_snapshots/backup_prod_snapshot"
SNAPJSON="/backup/aws/ec2_snapshots/backup_snapshot_prod_json.info"
AMIANDDATE="/backup/aws/ami/backup_prod_ami"
AMIJSON="/backup/aws/ami/backup_ami_prod_json.info"
RDSANDDATE="/backup/aws/rds_snapshots/backup_rds_prod_snapshot"
RDSJSON="/backup/aws/rds_snapshots/backup_rds_prod_snapshot_json.info"
SQLFILELIST=sql_prod_file_list
WWWFILELIST=www_prod_file_list

#JSON AND DATA STAGE
STAGESNAPANDDATE="/backup/aws/ec2_snapshots/backup_stage_snapshot"
STAGESNAPJSON="/backup/aws/ec2_snapshots/backup_snapshot_stage_json.info"
STAGEAMIANDDATE="/backup/aws/ami/backup_stage_ami"
STAGEAMIJSON="/backup/aws/ami/backup_ami_stage_json.info"
STAGERDSANDDATE="/backup/aws/rds_snapshots/backup_rds_stage_snapshot"
STAGERDSJSON="/backup/aws/rds_snapshots/backup_rds_stage_snapshot_json.info"
STAGESQLFILELIST=sql_stage_file_list
STAGEWWWFILELIST=www_stage_file_list

#LOGS
LOG=backup_prod_purging.log
STAGELOG=backup_stage_purging.log

#SNAPSHOT DATE SETTINGS
datecheck_14d=`date +%Y-%m-%d --date '10 days ago'`
datecheck_s_14d=`date --date="$datecheck_14d" +%s`
datecheck_30d=`date +%Y-%m-%d --date '30 days ago'`
datecheck_s_30d=`date --date="$datecheck_30d" +%s`
datecheck_7d=`date +%Y-%m-%d --date '7 days ago'`
datecheck_s_7d=`date --date="$datecheck_7d" +%s`

#=================================
#AWS EC2 PURGING SNAPSHOTS
#=================================

if ! [ -f ~/.aws/credentials ]
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Purging backup can not proceed. AWS authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${LOG}
else
	if [ ! -d "${SNAPLOCATION}" ]
	then
		mkdir -p ${SNAPLOCATION}
	fi

	echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Collecting Snapshot Information from AWS" | tee --append /backup/backup_logs/${LOG}
	
	snap_status=$(aws ec2 describe-snapshots --region ${region} --owner-ids ${ownerID} --filters Name=tag:${tagName},Values=${tagValue} > ${SNAPJSON} 2>&1)
	
	if [ "$?" -eq 0 ]
	then
		echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Running JQ Utility on Snapshot" | tee --append /backup/backup_logs/${LOG}
		
		cat ${SNAPJSON} | ${JQLOCATION}/jq-linux64 -r '.Snapshots[] | "\(.SnapshotId) \(.StartTime)"' > ${SNAPANDDATE}

		if [ "$?" -eq 0 ]
		then
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Running Verification of Snapshot ..." | tee --append /backup/backup_logs/${LOG}
			
			cat ${SNAPANDDATE} | while read snap
			do
					snapshot_id=`awk '{print $1}' <<< "$snap"`
					#echo ${snapshot_id}
					snapshot_date=`awk '{print $2}' <<< "$snap"`
					#echo ${snapshot_date}
					datecheck_s_old=`date "--date=${snapshot_date}" +%s`
					#echo ${datecheck_s_old}

					if (( ${datecheck_s_old} <= ${datecheck_s_30d} ));
					then
							echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Snapshot: ${snapshot_id} is 30 Days old. Purging ..." | tee --append /backup/backup_logs/${LOG}
							
							aws ec2 delete-snapshot --region ${region} --snapshot-id ${snapshot_id}
							
							if [ "$?" -eq 0	]
							then
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Snapshot: ${snapshot_id} is deleted." | tee --append /backup/backup_logs/${LOG}
							else
								echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Snapshot: ${snapshot_id} is not deleted due to an error." | tee --append /backup/backup_logs/${LOG}
							fi
					else
							echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Snapshot: ${snapshot_id} is not 30 days old" | tee --append /backup/backup_logs/${LOG}
					fi
			done
		else
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--JQ Utility on Snapshot Failed. Please verify that JSON file ( ${SNAPJSON} ) is created and has content inside." | tee --append /backup/backup_logs/${LOG}
		fi
	else
		echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Unable to gather information from AWS." | tee --append /backup/backup_logs/${LOG}
	fi
fi
 
#=================================
#AWS EC2 PURGING AMI'S
#=================================

if ! [ -f ~/.aws/credentials ]
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Purging backup can not proceed. AWS authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${LOG}
else
	if [ ! -d "${AMILOCATION}" ]
	then
		mkdir -p ${AMILOCATION}
	fi

	echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Collecting AMI Information from AWS" | tee --append /backup/backup_logs/${LOG}
	
	ami_status=$(aws ec2 describe-images --region ${region} --owners ${ownerID} --filters Name=tag:${amiTagName},Values=${amiTagValue} > ${AMIJSON} 2>&1)
	
	if [ "$?" -eq 0 ]
	then
		echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Running JQ Utility on AMI" | tee --append /backup/backup_logs/${LOG}
		
		cat ${AMIJSON} | ${JQLOCATION}/jq-linux64 -r '.Images[] | "\(.ImageId) \(.CreationDate) \(.BlockDeviceMappings[].Ebs.SnapshotId)"' > ${AMIANDDATE}

		if [ "$?" -eq 0 ]
		then
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Running Verification of AMI ..." | tee --append /backup/backup_logs/${LOG}
			
			cat ${AMIANDDATE} | while read ami
			do
					ami_id=`awk '{print $1}' <<< "$ami"`
					#echo ${ami_id}
					ami_date=`awk '{print $2}' <<< "$ami"`
					#echo ${ami_date}
					ami_snapshot=`awk '{print $3}' <<< "$ami"`
					#echo ${ami_snapshot}
					ami_datecheck_s_old=`date "--date=${ami_date}" +%s`
					#echo ${ami_datecheck_s_old}

					if (( ${ami_datecheck_s_old} <= ${datecheck_s_30d} ));
					then
							echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI: ${ami_id} is 30 Days old. Purging ..." | tee --append /backup/backup_logs/${LOG}
							
							aws ec2 deregister-image --region ${region} --image-id ${ami_id}
							
							if [ "$?" -eq 0	]
							then
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI: ${ami_id} is deleted." | tee --append /backup/backup_logs/${LOG}
								
								aws ec2 delete-snapshot --region ${region} --snapshot-id ${ami_snapshot}
								
								if [ "$?" -eq 0	]
								then
									echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI Snapshot: ${ami_snapshot} is deleted." | tee --append /backup/backup_logs/${LOG}
								else
									echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI Snapshot: ${ami_snapshot} is not deleted due to an error. Please delete the snapshot manually." | tee --append /backup/backup_logs/${LOG}
								fi
								
							else
								echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI: ${ami_id} is not deleted due to an error." | tee --append /backup/backup_logs/${LOG}
							fi
					else
							echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI: ${ami_id} is not 30 days old" | tee --append /backup/backup_logs/${LOG}
					fi
			done
		else
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--JQ Utility on AMI Failed. Please verify that JSON file ( ${AMIJSON} ) is created and has content inside." | tee --append /backup/backup_logs/${LOG}
		fi
	else
		echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Unable to gather information from AWS." | tee --append /backup/backup_logs/${LOG}
	fi
fi

#======================================================
#PURGING MANUAL SQL FILES IN BACKUP SERVER AND AWS S3
#======================================================
if ! [ -f ~/.aws/credentials ] 
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Purging backup can not proceed. AWS authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${LOG}
else
	if [ -d "${SQLBACKUP}" ]
	then

		if [ ! -d "${SQLLOCATION}" ]
		then
			mkdir -p ${SQLLOCATION}
		fi
		
		ls -l --time-style=+"%Y-%m-%dT%H:%M:%SZ" ${SQLBACKUP} | grep -v '^total' | grep -v ^d | awk '{print $7, $6}' > ${SQLLOCATION}${SQLFILELIST}
		
		if [ -s ${SQLLOCATION}${SQLFILELIST} ]
		then		
			if [ "$?" -eq 0 ]
			then
				echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--SQL File List: ${SQLLOCATION}${SQLFILELIST} was created." | tee --append /backup/backup_logs/${LOG}
				
				cat ${SQLLOCATION}${SQLFILELIST} | while read sql_file
				do
				
					sql_name=`awk '{print $1}' <<< "$sql_file"`
					#echo ${sql_name}
					sql_date=`awk '{print $2}' <<< "$sql_file"`
					#echo ${sql_date}
					sql_datecheck_s_old=`date "--date=${sql_date}" +%s`
					#echo ${sql_datecheck_s_old}

					if (( ${sql_datecheck_s_old} <= ${datecheck_s_30d} ));
						then
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL SQL File: ${sql_name} is 30 Days old. Purging ..." | tee --append /backup/backup_logs/${LOG}
								
								if [ -f "${SQLBACKUP}${sql_name}" ]
								then
									if [[ ${SQLBACKUP}${sql_name} == *.sql.gz ]]
									then
										rm -rf ${SQLBACKUP}${sql_name}
									else
										echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL SQL File: ${sql_name} is not deleted. File is not a sql.gz file." | tee --append /backup/backup_logs/${LOG}
										(exit 1)
									fi
								else
									(exit 1)
								fi
								
								if [ "$?" -eq 0	]
								then
									echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL SQL File: ${sql_name} is deleted." | tee --append /backup/backup_logs/${LOG}
									
									aws s3 rm s3://${S3BUCKET}/${S3SQLBACKUP}${sql_name} --quiet
									
									if [ "$?" -eq 0	]
									then
										echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 SQL File: ${sql_name} is deleted from AWS S3 Bucket ${S3BUCKET}." | tee --append /backup/backup_logs/${LOG}
										
										aws s3 rm s3://${S3BUCKETWEST}/${S3SQLBACKUP}${sql_name} --quiet
										
										if [ "$?" -eq 0	]
										then
											echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 SQL File: ${sql_name} is deleted from AWS S3 Bucket ${S3BUCKETWEST}." | tee --append /backup/backup_logs/${LOG}
										else
											echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 SQL File: ${sql_name} is not found in ${S3BUCKETWEST} bucket or could not be deleted. Please delete the file manually." | tee --append /backup/backup_logs/${LOG}
										fi
									else
										echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 SQL File: ${sql_name} is not found in ${S3BUCKET} bucket or could not be deleted. Please delete the file manually." | tee --append /backup/backup_logs/${LOG}
									fi
									
								else
									echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL SQL File: ${sql_name} is not deleted locally due to an error." | tee --append /backup/backup_logs/${LOG}
								fi
						else
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL SQL File: ${sql_name} is not 30 days old" | tee --append /backup/backup_logs/${LOG}
						fi
					
				done

			else
				echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Unable to create ${SQLLOCATION}${SQLFILELIST}. Please verify permissions for user or folder." | tee --append /backup/backup_logs/${LOG}
			fi
		else
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--File: ${SQLLOCATION}${SQLFILELIST} is empty. Backup Directory: ${SQLBACKUP} does not have MySQL Backups. " | tee --append /backup/backup_logs/${LOG}
		fi
	fi
fi

#======================================================
#PURGING MANUAL WWW FILES IN BACKUP SERVER AND AWS S3
#======================================================
if ! [ -f ~/.aws/credentials ] 
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Purging backup can not proceed. AWS authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${LOG}
else
	if [ -d "${WWWBACKUP}" ]
	then

		if [ ! -d "${WWWLOCATION}" ]
		then
			mkdir -p ${WWWLOCATION}
		fi
		
		ls -l --time-style=+"%Y-%m-%dT%H:%M:%SZ" ${WWWBACKUP} | grep -v '^total' | grep -v ^d | awk '{print $7, $6}' > ${WWWLOCATION}${WWWFILELIST}
		
		if [ -s ${WWWLOCATION}${WWWFILELIST} ]
		then		
			if [ "$?" -eq 0 ]
			then
				echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--WWW File List: ${WWWLOCATION}${WWWFILELIST} was created." | tee --append /backup/backup_logs/${LOG}
				
				cat ${WWWLOCATION}${WWWFILELIST} | while read www_file
				do
				
					www_name=`awk '{print $1}' <<< "$www_file"`
					#echo ${www_name}
					www_date=`awk '{print $2}' <<< "$www_file"`
					#echo ${www_date}
					www_datecheck_s_old=`date "--date=${www_date}" +%s`
					#echo ${www_datecheck_s_old}

					if (( ${www_datecheck_s_old} <= ${datecheck_s_7d} ));
						then
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL WWW File: ${www_name} is 7 Days old. Purging ..." | tee --append /backup/backup_logs/${LOG}
								
								if [ -f "${WWWBACKUP}${www_name}" ]
								then
									if [[ ${WWWBACKUP}${www_name} == *.tar.gz ]]
									then
										rm -rf ${WWWBACKUP}${www_name}
									else
										echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL WWW File: ${www_name} is not deleted. File is not a tar.gz file." | tee --append /backup/backup_logs/${LOG}
										(exit 1)
									fi
								else
									(exit 1)
								fi
								
								if [ "$?" -eq 0	]
								then
									echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL WWW File: ${www_name} is deleted." | tee --append /backup/backup_logs/${LOG}
									
									aws s3 rm s3://${S3BUCKET}/${S3WWWBACKUP}${www_name} --quiet
									
									if [ "$?" -eq 0	]
									then
										echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 WWW File: ${www_name} is deleted from AWS S3 Bucket ${S3BUCKET}." | tee --append /backup/backup_logs/${LOG}
										
										aws s3 rm s3://${S3BUCKETWEST}/${S3WWWBACKUP}${www_name} --quiet
										
										if [ "$?" -eq 0	]
										then
											echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 WWW File: ${www_name} is deleted from AWS S3 Bucket ${S3BUCKETWEST}." | tee --append /backup/backup_logs/${LOG}
										else
											echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 WWW File: ${www_name} is not found in ${S3BUCKETWEST} bucket or could not be deleted. Please delete the file manually." | tee --append /backup/backup_logs/${LOG}
										fi
									else
										echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 WWW File: ${www_name} is not found in ${S3BUCKET} bucket or could not be deleted. Please delete the file manually." | tee --append /backup/backup_logs/${LOG}
									fi
									
								else
									echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL WWW File: ${www_name} is not deleted locally due to an error." | tee --append /backup/backup_logs/${LOG}
								fi
						else
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL WWW File: ${www_name} is not 7 days old" | tee --append /backup/backup_logs/${LOG}
						fi
					
				done

			else
				echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Unable to create ${WWWLOCATION}${WWWFILELIST}. Please verify permissions for user or folder." | tee --append /backup/backup_logs/${LOG}
			fi
		else
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--File: ${WWWLOCATION}${WWWFILELIST} is empty. Backup Directory: ${WWWBACKUP} does not have www Backups. " | tee --append /backup/backup_logs/${LOG}
		fi
	fi
fi

#######################
#STAGE
#######################

#=================================
#AWS STAGE EC2 PURGING SNAPSHOTS
#=================================

if ! [ -f ~/.aws/credentials ]
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Purging backup can not proceed. AWS authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${STAGELOG}
else
	if [ ! -d "${SNAPLOCATION}" ]
	then
		mkdir -p ${SNAPLOCATION}
	fi

	echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Collecting Snapshot Information from AWS" | tee --append /backup/backup_logs/${STAGELOG}
	
	snap_status=$(aws ec2 describe-snapshots --region ${westregion} --owner-ids ${ownerID} --filters Name=tag:${tagName},Values=${tagStageValue} > ${STAGESNAPJSON} 2>&1)
	
	if [ "$?" -eq 0 ]
	then
		echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Running JQ Utility on Snapshot" | tee --append /backup/backup_logs/${STAGELOG}
		
		cat ${STAGESNAPJSON} | ${STAGEJQLOCATION}/jq-linux64 -r '.Snapshots[] | "\(.SnapshotId) \(.StartTime)"' > ${STAGESNAPANDDATE}

		if [ "$?" -eq 0 ]
		then
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Running Verification of Snapshot ..." | tee --append /backup/backup_logs/${STAGELOG}
			
			cat ${STAGESNAPANDDATE} | while read snap
			do
					snapshot_id=`awk '{print $1}' <<< "$snap"`
					#echo ${snapshot_id}
					snapshot_date=`awk '{print $2}' <<< "$snap"`
					#echo ${snapshot_date}
					datecheck_s_old=`date "--date=${snapshot_date}" +%s`
					#echo ${datecheck_s_old}

					if (( ${datecheck_s_old} <= ${datecheck_s_30d} ));
					then
							echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Snapshot: ${snapshot_id} is 30 Days old. Purging ..." | tee --append /backup/backup_logs/${STAGELOG}
							
							aws ec2 delete-snapshot --region ${westregion} --snapshot-id ${snapshot_id}
							
							if [ "$?" -eq 0	]
							then
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Snapshot: ${snapshot_id} is deleted." | tee --append /backup/backup_logs/${STAGELOG}
							else
								echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Snapshot: ${snapshot_id} is not deleted due to an error." | tee --append /backup/backup_logs/${STAGELOG}
							fi
					else
							echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Snapshot: ${snapshot_id} is not 30 days old" | tee --append /backup/backup_logs/${STAGELOG}
					fi
			done
		else
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--JQ Utility on Snapshot Failed. Please verify that JSON file ( ${STAGESNAPJSON} ) is created and has content inside." | tee --append /backup/backup_logs/${STAGELOG}
		fi
	else
		echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Unable to gather information from AWS." | tee --append /backup/backup_logs/${STAGELOG}
	fi
fi
 
#=================================
#AWS EC2 PURGING AMI'S
#=================================

if ! [ -f ~/.aws/credentials ]
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Purging backup can not proceed. AWS authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${STAGELOG}
else
	if [ ! -d "${AMILOCATION}" ]
	then
		mkdir -p ${AMILOCATION}
	fi

	echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Collecting AMI Information from AWS" | tee --append /backup/backup_logs/${STAGELOG}
	
	ami_status=$(aws ec2 describe-images --region ${westregion} --owners ${ownerID} --filters Name=tag:${amiTagName},Values=${amiStageTagValue} > ${STAGEAMIJSON} 2>&1)
	
	if [ "$?" -eq 0 ]
	then
		echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Running JQ Utility on AMI" | tee --append /backup/backup_logs/${STAGELOG}
		
		cat ${STAGEAMIJSON} | ${STAGEJQLOCATION}/jq-linux64 -r '.Images[] | "\(.ImageId) \(.CreationDate) \(.BlockDeviceMappings[].Ebs.SnapshotId)"' > ${STAGEAMIANDDATE}

		if [ "$?" -eq 0 ]
		then
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Running Verification of AMI ..." | tee --append /backup/backup_logs/${STAGELOG}
			
			cat ${STAGEAMIANDDATE} | while read ami
			do
					ami_id=`awk '{print $1}' <<< "$ami"`
					#echo ${ami_id}
					ami_date=`awk '{print $2}' <<< "$ami"`
					#echo ${ami_date}
					ami_snapshot=`awk '{print $3}' <<< "$ami"`
					#echo ${ami_snapshot}
					ami_datecheck_s_old=`date "--date=${ami_date}" +%s`
					#echo ${ami_datecheck_s_old}

					if (( ${ami_datecheck_s_old} <= ${datecheck_s_30d} ));
					then
							echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI: ${ami_id} is 30 Days old. Purging ..." | tee --append /backup/backup_logs/${STAGELOG}
							
							aws ec2 deregister-image --region ${westregion} --image-id ${ami_id}
							
							if [ "$?" -eq 0	]
							then
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI: ${ami_id} is deleted." | tee --append /backup/backup_logs/${STAGELOG}
								
								aws ec2 delete-snapshot --region ${westregion} --snapshot-id ${ami_snapshot}
								
								if [ "$?" -eq 0	]
								then
									echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI Snapshot: ${ami_snapshot} is deleted." | tee --append /backup/backup_logs/${STAGELOG}
								else
									echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI Snapshot: ${ami_snapshot} is not deleted due to an error. Please delete the snapshot manually." | tee --append /backup/backup_logs/${STAGELOG}
								fi
								
							else
								echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI: ${ami_id} is not deleted due to an error." | tee --append /backup/backup_logs/${STAGELOG}
							fi
					else
							echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI: ${ami_id} is not 30 days old" | tee --append /backup/backup_logs/${STAGELOG}
					fi
			done
		else
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--JQ Utility on AMI Failed. Please verify that JSON file ( ${STAGEAMIJSON} ) is created and has content inside." | tee --append /backup/backup_logs/${STAGELOG}
		fi
	else
		echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Unable to gather information from AWS." | tee --append /backup/backup_logs/${STAGELOG}
	fi
fi

#======================================================
#PURGING MANUAL SQL FILES IN BACKUP SERVER AND AWS S3
#======================================================
if ! [ -f ~/.aws/credentials ] 
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Purging backup can not proceed. AWS authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${STAGELOG}
else
	if [ -d "${STAGESQLBACKUP}" ]
	then

		if [ ! -d "${SQLLOCATION}" ]
		then
			mkdir -p ${SQLLOCATION}
		fi
		
		ls -l --time-style=+"%Y-%m-%dT%H:%M:%SZ" ${STAGESQLBACKUP} | grep -v '^total' | grep -v ^d | awk '{print $7, $6}' > ${SQLLOCATION}${STAGESQLFILELIST}
		
		if [ -s ${SQLLOCATION}${STAGESQLFILELIST} ]
		then		
			if [ "$?" -eq 0 ]
			then
				echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--SQL File List: ${SQLLOCATION}${STAGESQLFILELIST} was created." | tee --append /backup/backup_logs/${STAGELOG}
				
				cat ${SQLLOCATION}${STAGESQLFILELIST} | while read sql_file
				do
				
					sql_name=`awk '{print $1}' <<< "$sql_file"`
					#echo ${sql_name}
					sql_date=`awk '{print $2}' <<< "$sql_file"`
					#echo ${sql_date}
					sql_datecheck_s_old=`date "--date=${sql_date}" +%s`
					#echo ${sql_datecheck_s_old}

					if (( ${sql_datecheck_s_old} <= ${datecheck_s_30d} ));
						then
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL SQL File: ${sql_name} is 30 Days old. Purging ..." | tee --append /backup/backup_logs/${STAGELOG}
								
								if [ -f "${STAGESQLBACKUP}${sql_name}" ]
								then
									if [[ ${STAGESQLBACKUP}${sql_name} == *.sql.gz ]]
									then
										rm -rf ${STAGESQLBACKUP}${sql_name}
									else
										echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL SQL File: ${sql_name} is not deleted. File is not a sql.gz file." | tee --append /backup/backup_logs/${STAGELOG}
										(exit 1)
									fi
								else
									(exit 1)
								fi
								
								if [ "$?" -eq 0	]
								then
									echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL SQL File: ${sql_name} is deleted." | tee --append /backup/backup_logs/${STAGELOG}
									
									aws s3 rm s3://${S3BUCKET}/${S3SQLBACKUP}${sql_name} --quiet
									
									if [ "$?" -eq 0	]
									then
										echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 SQL File: ${sql_name} is deleted from AWS S3 Bucket ${S3BUCKET}/${S3SQLBACKUP}." | tee --append /backup/backup_logs/${STAGELOG}
										
										aws s3 rm s3://${S3BUCKETWEST}/${S3SQLBACKUP}${sql_name} --quiet
										
										if [ "$?" -eq 0	]
										then
											echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 SQL File: ${sql_name} is deleted from AWS S3 Bucket ${S3BUCKETWEST}/${S3SQLBACKUP}." | tee --append /backup/backup_logs/${STAGELOG}
										else
											echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 SQL File: ${sql_name} is not found in ${S3BUCKETWEST}/${S3SQLBACKUP} bucket or could not be deleted. Please delete the file manually." | tee --append /backup/backup_logs/${STAGELOG}
										fi
									else
										echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 SQL File: ${sql_name} is not found in ${S3BUCKET}/${S3SQLBACKUP} bucket or could not be deleted. Please delete the file manually." | tee --append /backup/backup_logs/${STAGELOG}
									fi
									
								else
									echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL SQL File: ${sql_name} is not deleted locally due to an error." | tee --append /backup/backup_logs/${STAGELOG}
								fi
						else
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL SQL File: ${sql_name} is not 30 days old" | tee --append /backup/backup_logs/${STAGELOG}
						fi
					
				done

			else
				echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Unable to create ${SQLLOCATION}${STAGESQLFILELIST}. Please verify permissions for user or folder." | tee --append /backup/backup_logs/${STAGELOG}
			fi
		else
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--File: ${SQLLOCATION}${STAGESQLFILELIST} is empty. Backup Directory: ${STAGESQLBACKUP} does not have MySQL Backups. " | tee --append /backup/backup_logs/${STAGELOG}
		fi
	fi
fi

#======================================================
#PURGING MANUAL WWW FILES IN BACKUP SERVER AND AWS S3
#======================================================
if ! [ -f ~/.aws/credentials ] 
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Purging backup can not proceed. AWS authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${STAGELOG}
else
	if [ -d "${STAGEWWWBACKUP}" ]
	then

		if [ ! -d "${WWWLOCATION}" ]
		then
			mkdir -p ${WWWLOCATION}
		fi
		
		ls -l --time-style=+"%Y-%m-%dT%H:%M:%SZ" ${STAGEWWWBACKUP} | grep -v '^total' | grep -v ^d | awk '{print $7, $6}' > ${WWWLOCATION}${STAGEWWWFILELIST}
		
		if [ -s ${WWWLOCATION}${STAGEWWWFILELIST} ]
		then		
			if [ "$?" -eq 0 ]
			then
				echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--WWW File List: ${WWWLOCATION}${STAGEWWWFILELIST} was created." | tee --append /backup/backup_logs/${STAGELOG}
				
				cat ${WWWLOCATION}${STAGEWWWFILELIST} | while read www_file
				do
				
					www_name=`awk '{print $1}' <<< "$www_file"`
					#echo ${www_name}
					www_date=`awk '{print $2}' <<< "$www_file"`
					#echo ${www_date}
					www_datecheck_s_old=`date "--date=${www_date}" +%s`
					#echo ${www_datecheck_s_old}

					if (( ${www_datecheck_s_old} <= ${datecheck_s_7d} ));
						then
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL WWW File: ${www_name} is 7 Days old. Purging ..." | tee --append /backup/backup_logs/${STAGELOG}
								
								if [ -f "${STAGEWWWBACKUP}${www_name}" ]
								then
									if [[ ${STAGEWWWBACKUP}${www_name} == *.tar.gz ]]
									then
										rm -rf ${STAGEWWWBACKUP}${www_name}
									else
										echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL WWW File: ${www_name} is not deleted. File is not a tar.gz file." | tee --append /backup/backup_logs/${STAGELOG}
										(exit 1)
									fi
								else
									(exit 1)
								fi
								
								if [ "$?" -eq 0	]
								then
									echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL WWW File: ${www_name} is deleted." | tee --append /backup/backup_logs/${STAGELOG}
									
									aws s3 rm s3://${S3BUCKET}/${S3WWWBACKUP}${www_name} --quiet
									
									if [ "$?" -eq 0	]
									then
										echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 WWW File: ${www_name} is deleted from AWS S3 Bucket ${S3BUCKET}/${S3WWWBACKUP}." | tee --append /backup/backup_logs/${STAGELOG}
										
										aws s3 rm s3://${S3BUCKETWEST}/${S3WWWBACKUP}${www_name} --quiet
										
										if [ "$?" -eq 0	]
										then
											echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 WWW File: ${www_name} is deleted from AWS S3 Bucket ${S3BUCKETWEST}/${S3WWWBACKUP}." | tee --append /backup/backup_logs/${STAGELOG}
										else
											echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 WWW File: ${www_name} is not found in ${S3BUCKETWEST}/${S3WWWBACKUP} bucket or could not be deleted. Please delete the file manually." | tee --append /backup/backup_logs/${STAGELOG}
										fi
									else
										echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AWS S3 WWW File: ${www_name} is not found in ${S3BUCKET}/${S3WWWBACKUP} bucket or could not be deleted. Please delete the file manually." | tee --append /backup/backup_logs/${STAGELOG}
									fi
									
								else
									echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL WWW File: ${www_name} is not deleted locally due to an error." | tee --append /backup/backup_logs/${STAGELOG}
								fi
						else
								echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--LOCAL WWW File: ${www_name} is not 7 days old" | tee --append /backup/backup_logs/${STAGELOG}
						fi
					
				done

			else
				echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Unable to create ${WWWLOCATION}${STAGEWWWFILELIST}. Please verify permissions for user or folder." | tee --append /backup/backup_logs/${STAGELOG}
			fi
		else
			echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--File: ${WWWLOCATION}${STAGEWWWFILELIST} is empty. Backup Directory: ${STAGEWWWBACKUP} does not have www Backups. " | tee --append /backup/backup_logs/${STAGELOG}
		fi
	fi
fi




