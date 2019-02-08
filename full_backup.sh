#!/bin/bash

db_user="root"
myisam_db=test
db_passwd="root"
host=localhost
mkdir -p full_backup/mysql
backup_dir=full_backup/mysql
log_file=full_backup/mysql/mysql_backup.log
keep_days=7
mysql=$(which mysql)
mysqldump=$(which mysqldump)
export PATH=/usr/local/mysql/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
dbs=$(echo $db_list|tr '\n' ' ')
myisam_dump_file=$backup_dir/MyISAM-$(date +"%Y-%m-%d")-full.sql.gz
innodb_dump_file=$backup_dir/InnoDB-$(date +"%Y-%m-%d")-full.sql.gz
old_file_myisam=$backup_dir/MyISAM-$(date --date="$keep_days days ago" +"%Y-%m-%d")-full.sql.gz
old_file_innodb=$backup_dir/InnoDB-$(date --date="$keep_days days ago" +"%Y-%m-%d")-full.sql.gz
info() {
  if [ $? -eq 0 ];then
    echo "Full backup $1 successfully." >>$log_file
  else
    echo "Full backup $1 failed." >>$log_file
    echo "Full backup $1 failed."|mail -s "Full backup $2 failed" root@localhost
  fi
}


delete_old_files() {
if [ -f $1 ];then
  rm -rf $1
  echo "Delete old file '$1' successfully" >>$log_file
fi
 
}
 
start_time=$(date +"%F %H:%M:%S")
[ ! -d $backup_dir ] && mkdir -p $backup_dir
[ ! -f $log_file ] && touch $log_file
echo "Starting mysql full backup database at $start_time" >>$log_file
$mysqldump -h$host -u$db_user -p$db_passwd -F -B -x --events --triggers \
--routines --master-data=2 $myisam_db|gzip >$myisam_dump_file 2>>$log_file 
info $myisam_dump_file "MyISAM"
$mysqldump -h$host -u$db_user -p$db_passwd -F -B --single-transaction \
--events --triggers --routines --master-data=2 $dbs|gzip >$innodb_dump_file 2>>$log_file 
info $innodb_dump_file "InnoBD"
stop_time=$(date +"%F %H:%M:%S")
echo "End mysql full backup database at $stop_time" >>$log_file
delete_old_files $old_file_myisam
delete_old_files $old_file_innodb
echo " " >>$log_file
