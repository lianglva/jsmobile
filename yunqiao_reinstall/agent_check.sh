#/bin/bash

source /etc/profile

script_path=`dirname $0`
script_name=`basename $0`

#agent检查进程
agent_pid=`ps axu |grep itcloudagent| grep -Ev 'grep|version_check' |awk '{print $2}'`
if [  ${agent_pid} ]; then
echo "agent进程存在(agent)"
fi

#version_check进程检查
agent_pid=`ps axu |grep itcloudagent| grep  'version_check' |awk '{print $2}'`
if [  ${agent_pid} ]; then
echo "agent进程存在(vck)"
fi

#检查安装目录
##查看安装目录是否为 /usr/local/itcloudagent
if [ -d /usr/local/itcloudagent ]; then
echo "agent安装目录为'/usr/local/itcloudagent'"
fi

##查看安装目录是否为 /opt/itcloudagent
if [ -d /opt/itcloudagent ]; then
echo "agent安装目录为'/opt/itcloudagent'"
fi

##查看安装目录是否为 $HOME/itcloudagent
if [ -d $HOME/itcloudagent ]; then
echo "agent安装目录为'$HOME/itcloudagent'"
fi

#redhat检查计划任务
grep 'itcloudagent/bin/daemon'  /var/spool/cron/root >/dev/null 2>&1
if [ $? -eq 0 ]; then
echo "itcloudagent自巡检已写入crontab(redhat)"
fi

#suse检查计划任务
grep 'itcloudagent/bin/daemon'  /var/spool/cron/tabs/root >/dev/null 2>&1
if [ $? -eq 0 ]; then
echo "itcloudagent自巡检已写入crontab(suse)"
fi

#redhat检查开机自启文件
grep 'itcloudagent/bin/daemon' /etc/rc.local  >/dev/null 2>&1
if [ $? -eq 0 ]; then
echo "itcloud已添加开机自启(redhat)"
fi

#suse检查开机自启文件
grep 'itcloudagent/bin/daemon' /etc/init.d/boot.local  >/dev/null 2>&1
if [ $? -eq 0 ]; then
echo "itcloud已添加开机自启(suse)"
fi

#执行完毕，删除脚本
#rm -f $script_path/$script_name