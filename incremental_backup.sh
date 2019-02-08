#!/bin/bash
# Program
# use cp to backup mysql data everyday!
# History
# Path
# 
db_user="root"
myisam_db=test
db_passwd="root"
host=localhost
mkdir -p incremental_backup/mysql/backup/daily
mkdir -p incremental_backup/mysql/data
backup_dir=incremental_backup/mysql/backup
BakDir=incremental_backup/mysql/backup/daily
BinDir=/var/lib/mysql    
LogFile=incremental_backup/mysql/backup/bak.log
BinFile=/var/lib/mysql/mysql-bin.index
/usr/bin/mysqladmin -uroot -proot flush-logs
keep_days=7
mysql=$(which mysql)
mysqldump=$(which mysqldump)
export PATH=/usr/local/mysql/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin
dbs=$(echo $db_list|tr '\n' ' ')
#used for create mysql-bin.00000*
Counter=`wc -l $BinFile |awk '{print $1}'`
NextNum=0

myisam_dump_file=$backup_dir/MyISAM-$(date +"%Y-%m-%d")-inc.sql.gz
innodb_dump_file=$backup_dir/InnoDB-$(date +"%Y-%m-%d")-inc.sql.gz
old_file_myisam=$backup_dir/MyISAM-$(date --date="$keep_days days ago" +"%Y-%m-%d")-inc.sql.gz
old_file_innodb=$backup_dir/InnoDB-$(date --date="$keep_days days ago" +"%Y-%m-%d")-inc.sql.gz

info() {
  if [ $? -eq 0 ];then
    echo "incremental backup $1 successfully." >>$LogFile
  else
    echo "incremental backup $1 failed." >>$LogFile
    echo "incremental backup $1 failed."|mail -s "Full backup $2 failed" root@localhost
  fi
}
delete_old_files() {
if [ -f $1 ];then
  rm -rf $1
  echo "Delete old file '$1' successfully" >>$LogFile
fi
 
}

#compare $Counter,$NextNum existed or newest！
for file in `cat $BinFile`
do
    base=`basename $file`
    #basename  for acquire mysql-bin.00000*filename，drop./mysql-bin.000005 front./
    NextNum=`expr $NextNum + 1`
    if [ $NextNum -eq $Counter ]
    then
        echo $base skip! >> $LogFile
    else
        dest=$BakDir/$base
        if(test -e $dest)
        #test -e  used for test file existence，if so,then write exist! to $LogFile
        then
            echo $base exist! >> $LogFile
        else
            cp $BinDir/$base $BakDir
            echo $base copying >> $LogFile
         fi
     fi
done
#echo `date +"%Y年%m月%d日 %H:%M:%S"` $Next Bakup succ! >> $LogFile

start_time=$(date +"%F %H:%M:%S")
[ ! -d $backup_dir ] && mkdir -p $backup_dir
[ ! -f $LogFile ] && touch $LogFile
echo "Starting mysql incremental backup database at $start_time" >>$LogFile
$mysqldump -h$host -u$db_user -p$db_passwd -F -B -x --events --triggers \
--routines --master-data=2 $myisam_db|gzip >$myisam_dump_file 2>>$LogFile 
info $myisam_dump_file "MyISAM"
$mysqldump -h$host -u$db_user -p$db_passwd -F -B --single-transaction \
--events --triggers --routines --master-data=2 $dbs|gzip >$innodb_dump_file 2>>$LogFile 
info $innodb_dump_file "InnoBD"
stop_time=$(date +"%F %H:%M:%S")
echo "End mysql incremental backup database at $stop_time" >>$LogFile
delete_old_files $old_file_myisam
delete_old_files $old_file_innodb
echo " " >>$LogFile
