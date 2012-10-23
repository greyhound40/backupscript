#!/bin/sh
# testing git push feature and ssh keys
dn=`date +%u`
hst=$(hostname | awk '{print $1}')
dt=`date +%m-%d-%Y`
df='/backups/daily/'
wf='/backups/weekly'
mf='/backups/monthly'
tmpdir='/tempbackup'
lf='/backups/logs'
wkndlog="/backups/logs/${hst}_weekly.log"
mdump=$(which mysqldump)
bklimit=75
bkuse=$(df -h | egrep '/backup' | awk '{print $5}' | cut -d '%' -f 1)


if [ $bklimit -ge $bklimit ]; then
  for x in $(find $wf -type f -iname "*.gz" -exec stat -t {} \; | sort -n -k 13,13 | head --lines=1 | sed 's/\ .*$//'); do ls ${x} > $lf/oldest.log;done
  for x in $(find $mf -type f -iname "*.gz" -exec stat -t {} \; | sort -n -k 13,13 | head --lines=1 | sed 's/\ .*$//'); do ls ${x} >> $lf/oldest.log;done
  cat $lf/oldest.log | mail -s "Backup Limit Reached on ${hst}" ryantiffany@gmail.com
  echo "Oh noes, it all broke." >> $lf/backup_error.log
  exit 1
fi

if [ ! -d "$lf" ]; then
  mkdir $lf
fi

if [ -e "$df/$dt" ]; then
rm -Rf $df/$dt
fi
mkdir -p $df/$dt

if [ -e "$wf/$dt" ]; then
rm -Rf $wf/$dt
fi
mkdir -p $wf/$dt

if [ -e "$mf/$dt" ]; then
rm -Rf $mf/$dt
fi
mkdir -p $mf/$dt

if [ ! -d "$tmpdir" ]; then
        mkdir $tmpdir
fi

dumpdb() {
  exec 6>&1
  dbex="information_schema"
  dbs="`mysql -uroot -p`cat /root/.mycnf` --batch -N -e "show databases"`"
  for i in $dbex
  do
  dbs=`echo $dbs | sed "s/\b$i\b//g"`
  done
  for i in $dbs
  do
  mysqldump -uroot -p`cat /root/.mycnf` $i | gzip -c > $df/$dt/$i.sql.tar.gz
  done
  exec 1>&6 6>&- # Restore stdout and close file descriptor #6
}

dailybackup () {
  rsync -azv /home/ryan $df/$dt > $df/${dt}_log
  rsync -azv /root $df/$dt >> $df/${dt}_log
  rsync -azv /srv/http $df/$dt >> $df/${dt}_log
  rsync -azv /etc $df/$dt >> $df/${dt}_log
  dumpdb
}

weeklybackup(){
        tar czf $wf/${hst}_${dt}_weekly.tar.gz $df
 }

monthlybackup(){
  tar czv $mf/Monthly_${dt}_${hst}_tar.gz $wf
  find /backups -follow -iname '*.gz' | awk '{ print $1 }' > $lf/${dt}.log
  cat $lf/${dt}.log | mail -s "Current Backup Usage"  ryantiffany@gmail.com
}

cleanup() {
  find $df -type d -mtime +13 -exec rm -Rf {} \;
  find $wf -type f -iname "*.gz" -mtime +28 -exec rm -Rf {} \;
  find $mf -type f -iname "*.gz" -mtime +180 -exec rm -Rf {} \;
  find /backups -follow -iname '*.gz' | awk '{ print $1 }' > $lf/${dt}.log
  cat $lf/${dt}.log | mail -s "Current Backup Usage"  ryantiffany@gmail.com
}


if [ `date +%d` = "01" ]
  then
  monthlybackup
else
  case "$dn" in
 "1" | "2" | "3" | "4" | "5" )
  dailybackup
  ;;
 "6" )
  weeklybackup
  ;;
 "7" )
  cleanup
  ;;
esac
fi
