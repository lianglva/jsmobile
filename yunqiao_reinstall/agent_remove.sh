#/bin/bash

source /etc/profile

script_path=`dirname $0`
script_name=`basename $0`

if which mv >/dev/null 2>&1; then
    mv="mv"
else
    mv="/bin/mv"
fi
mv_command=`which mv |tail -1`
#获取当前用户
user_id=`whoami`
#获取agent安装目录
agent_dir=`ps axu |grep 'itcloudagent/bin/version_check' |grep  -v grep  |awk '{print $NF}' |awk -F'/itcloudagent' '{print $1}'`
#清理当前用户crontab
crontab  -l | grep -v '/opt/yunqiao/itcloudagent/bin/daemon'  | crontab  -
crontab  -l | grep -v '/usr/local/itcloudagent/bin/daemon'  | crontab  -
#清理yunqiao用户crontab
crontab -u yunqiao -l | grep -v '/opt/yunqiao/itcloudagent/bin/daemon'  | crontab -u yunqiao -
crontab -u yunqiao -l | grep -v '/usr/local/itcloudagent/bin/daemon'  | crontab -u yunqiao -
#清理root用户crontab
crontab -u root -l | grep -v '/opt/yunqiao/itcloudagent/bin/daemon'  | crontab -u root -
crontab -u root -l | grep -v '/usr/local/itcloudagent/bin/daemon'  | crontab -u root -
#清理agent开机自启
#redhat
sed -i  '/itcloudagent\/bin\/daemon/d'  /etc/rc.local >/dev/null 2>&1
#suse
sed -i  '/itcloudagent\/bin\/daemon/d'  /etc/init.d/boot.local >/dev/null 2>&1
#停止agent程序
kill -9 `ps axu |grep itcloudagent |grep -v grep |awk '{print $2}'` > /dev/null 2>&1 &
mkdir /tmp/itcloudagent >/dev/null 2>&1 -p
#卸载云窍agent
${mv_command} -b /opt/yunqiao/itcloudagent -f  /tmp/itcloudagent/itcloudagent_de1  >/dev/null 2>&1
${mv_command} -b /opt/yunqiao/itcloudagent-1.0.0.tar.gz -f  /tmp/itcloudagent/itcloudagent_de2  >/dev/null 2>&1
#卸载当前运行agent
${mv_command} -b ${agent_dir}/itcloudagent  -f /tmp/itcloudagent/itcloudagent_de3  >/dev/null 2>&1
${mv_command} -b ${agent_dir}/itcloudagent-1.0.0.tar.gz  -f /tmp/itcloudagent/itcloudagent_de4  >/dev/null 2>&1
#卸载历史版本agent
${mv_command} -b /usr/local/itcloudagent -f  /tmp/itcloudagent/itcloudagent_de5  >/dev/null 2>&1
${mv_command} -b /usr/local/itcloudagent-1.0.0.tar.gz -f  /tmp/itcloudagent/itcloudagent_de6  >/dev/null 2>&1
${mv_command} -b /tmp/itcloudagent -f  /tmp/itcloudagent/itcloudagent_de7  >/dev/null 2>&1
${mv_command} -b /tmp/itcloudagent-1.0.0.tar.gz -f  /tmp/itcloudagent/itcloudagent_de8  >/dev/null 2>&1
#清理历史版本日志信息
${mv_command} -b /tmp/logs/agent.log*  -f  /tmp/itcloudagent/itcloudagent_de9   >/dev/null 2>&1
${mv_command} -b /tmp/logs/itcloudagent.log*  -f  /tmp/itcloudagent/itcloudagent_de10   >/dev/null 2>&1
${mv_command} -b /logs/agent.log*  -f  /tmp/itcloudagent/itcloudagent_de11   >/dev/null 2>&1
${mv_command} -b /logs/itcloudagent.log*  -f  /tmp/itcloudagent/itcloudagent_de12   >/dev/null 2>&1
${mv_command} -b /usr/logs/agent.log*  -f  /tmp/itcloudagent/itcloudagent_de13   >/dev/null 2>&1
${mv_command} -b /usr/logs/itcloudagent.log*  -f  /tmp/itcloudagent/itcloudagent_de14   >/dev/null 2>&1
${mv_command} -b /usr/local/logs/agent.log*  -f  /tmp/itcloudagent/itcloudagent_de15   >/dev/null 2>&1
${mv_command} -b /usr/local/logs/itcloudagent.log*  -f  /tmp/itcloudagent/itcloudagent_de16   >/dev/null 2>&1
${mv_command} -b /tmp/itcloudagent*   -f /tmp/itcloudagent/itcloudagent_de17  >/dev/null 2>&1
${mv_command} -b /tmp/itcloudagent -f /tmp/itcloud_bakup  >/dev/null 2>&1
rm -rf /tmp/itcloud_bakup/


#清理crontab注释
crontab -l |grep -v 'itcloudagent/bin/daemon'| grep -v '^# DO NOT EDIT THIS FILE' |grep -v '^# (- installed' | grep -v '^# (Cron' | grep -v '^# (/var/spool/cron/tabs'  | crontab -
crontab -u yunqiao -l |grep -v 'itcloudagent/bin/daemon'| grep -v '^# DO NOT EDIT THIS FILE' |grep -v '^# (- installed' | grep -v '^# (Cron' | grep -v '^# (/var/spool/cron/tabs' | crontab -u yunqiao -

echo "itcloudagent已清理完毕！"

#执行完毕，删除脚本
rm -f $script_path/$script_name


