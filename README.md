Jurski NYC AWS Backup Scripts
=========

A toolkit of scripts to backup AWS EC2, RDS, and local MySQL and WWW Data from Apache

## Features

*jurski-nyc-aws-backup-scripts* brings a toolkit of solutions for all your aws backup problems

 * Update automatically AWS CLI and PIP
 * Using AWS CLI creates AWS EC2 Snapshot 
 * Using AWS CLI creates AWS EC2 AMIs
 * Using AWS CLI creates AWS RDS Snapshot
 * Using AWS CLI creates MySQL Dump and Stores it in 2 Buckets in S3 (Two different regions can be used)
 * Using AWS CLI creates WWW Data Dump from Apache /var/www/html directory and stores it in 2 Buckets in S3 (Two different regions can be used)
 * Using AWS CLI cleanup script of all AWS AMI, Snapshots, WWW Data, MySQL Dumps every 30 days. Cleans up S3 and local copies on the backup server
 

## Requirements

 * Needs to configure the Variables in the Scripts to point to correct instance and volume IDs, S3 Buckets, backup folders, and mysql configurations
 * Latest AWS CLI installed using PIP
 * Python
 * Active AWS Account and IAM User to communicate to AWS

## Installation
Coming Soon
