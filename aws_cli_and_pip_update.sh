#!/bin/bash
#Created by Piotr Jurski
#JURSKI NYC - www.jurskinyc.com
#LICENSE Apache License 2.0
#
#READ ME FIRST!
#Do not update with Notepad++ use 'vi' on Putty
#IF ERROR OCCURS when running: (bash: ./backup.sh: /bin/bash^M: bad interpreter: No such file or directory) 
#USE "sed -i -e 's/\r$//' aws_cli_and_pip_update.sh" command

#==========================
#AWS EC2 BACKUP PROCESS
#==========================
LOG=backup_aws_pip_update.log
LOGLOCATION=/backup/backup_logs/

if [ ! -d "${LOGLOCATION}" ]
then
	mkdir -p ${LOGLOCATION}
fi

#Update PIP and AWS CLI if outdated
echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Starting the PIP and AWS CLI update ..."| tee --append /backup/backup_logs/${LOG}
pip install --upgrade pip 2>&1 >/dev/null
pip install --upgrade awscli 2>&1 >/dev/null
echo "INFO: "`TZ=":America/New_York" date +"%Y-%m-%d-%r"`"--Update for PIP and AWS CLI has been completed."| tee --append /backup/backup_logs/${LOG}