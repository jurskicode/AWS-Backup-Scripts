#!/bin/bash
#Created by Piotr Jurski
#JURSKI NYC - www.jurskinyc.com
#LICENSE Apache License 2.0
#
#READ ME FIRST!
#Do not update with Notepad++ use 'vi' on Putty
#IF ERROR OCCURS when running: (bash: ./backup.sh: /bin/bash^M: bad interpreter: No such file or directory) 
#USE "sed -i -e 's/\r$//' ec2_prod_manual_www_backup.sh" command

#FILL OUT THE KEYS, IPs, AND BUCKET NAMES

#Date
current_date=$(TZ=":America/New_York" date +%Y%m%d-%I%M%p)

FILE=${current_date}_www_prod_backup.tar.gz

ssh -i /root/.ssh/TYPEYOURKEYFILEHERE.pem ec2-user@TYPEIPOFSERVERTOBACKUP <<EOF
tar -zcvf /backup/www_backup/${FILE} /var/www/html
EOF

scp -i /root/.ssh/TYPEYOURKEYFILEHERE.pem ec2-user@TYPEIPOFSERVERTOBACKUP:/backup/www_backup/${FILE} /backup/www_backup/production

ssh -i /root/.ssh/TYPEYOURKEYFILEHERE.pem ec2-user@TYPEIPOFSERVERTOBACKUP <<EOF
rm -rf /backup/www_backup/${FILE}
EOF

aws s3 cp /backup/www_backup/production/${FILE} s3://BUCKETNAME/www_backup/${FILE} --acl private --output text --query ETag

aws s3 cp /backup/www_backup/production/${FILE} s3://SECONDBUCKETNAME/www_backup/${FILE} --acl private --output text --query ETag
