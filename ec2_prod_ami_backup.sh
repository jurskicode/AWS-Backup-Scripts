#!/bin/bash
#Created by Piotr Jurski
#JURSKI NYC - www.jurskinyc.com
#LICENSE Apache License 2.0
#
#READ ME FIRST!
#Do not update with Notepad++ use 'vi' on Putty
#IF ERROR OCCURS when running: (bash: ./backup.sh: /bin/bash^M: bad interpreter: No such file or directory) 
#USE "sed -i -e 's/\r$//' ec2_prod_ami_backup.sh" command

#Production Server Info (MODIFY SETTINGS HERE)
prod_instance_id=""
prod_volume_01=""
prod_volume_02=""
prod_region=''

#Date
current_date=$(TZ=":America/New_York" date +%Y-%m-%d-%I-%M-%S-%p)
LOG=backup_prod_ami.log
LOGLOCATION=/backup/backup_logs/

#Configurations
prod_image_name="PROD_AMI_${current_date}"
prod_image_description="PROD_SERVER_AMI_IMAGE"

#Tags
prod_tag_ami_name="Key=Name,Value=PROD_AMI_Backup"
prod_tag_date="Key=Date,Value=${current_date}"

#==========================
#AWS EC2 BACKUP PROCESS
#==========================



if ! [ -f ~/.aws/credentials ]
then
	echo "ERROR: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Backup cannot be created because aws authantication is not configured. Please run \"aws configure\" to set up AWS communication." | tee --append /backup/backup_logs/${LOG}
else
	if [ ! -d "${LOGLOCATION}" ]
	then
		mkdir -p ${LOGLOCATION}
	fi
	#./ec2-automate-backup.sh -v ${prod_volume_01} ${prod_volume_02}

	#Create Flat Server AMI
	echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Starting the AMI image creation ..." | tee --append /backup/backup_logs/${LOG}
	
	ami_id=$(aws ec2 create-image --instance-id ${prod_instance_id} --region ${prod_region} --name ${prod_image_name} --description ${prod_image_description} --no-reboot --output text --query ImageId 2>&1)

	#Tag the AMI image
	aws ec2 create-tags --region ${prod_region} --resources ${ami_id} --tags ${prod_tag_ami_name} ${prod_tag_date}

	#Confirmation to the User
	echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--AMI image id: "${ami_id}" was created." | tee --append /backup/backup_logs/${LOG}
fi





