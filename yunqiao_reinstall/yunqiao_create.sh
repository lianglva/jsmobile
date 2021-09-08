#!/bin/bash

###############################################################
# 新建“基础平台部IT云专业网管sudo账号”监控账号yunqiao，并赋予sudo权限
###############################################################
username="yunqiao"
password="LA1i@s9Df!j1s"
script_path=`dirname $0`
script_name=`basename $0`
date_time=`date +%F`


source /etc/profile

# 添加用户
if id -u ${username} >/dev/null 2>&1; then

echo "${username}用户已存在"

else

#创建zznode用户
useradd -d /opt/${username} -m -s /bin/bash   ${username}
# 给用户设置密码
# echo ${password} | passwd --stdin ${username}
echo "$username:$password" | chpasswd
echo "用户创建成功!"

fi

result=0
# 获取当前服务器raid控制器名称
 
extra_command="/opt/yunqiao/smartctl,/opt/yunqiao/hpssacli,/opt/yunqiao/MegaCli64,/opt/yunqiao/perccli64,/opt/yunqiao/storcli64,/bin/css-status.sh,/bin/shannon-status,/sbin/hioadm,/usr/sbin/nvme,/usr/sbin/dmidecode"
  
# 用户赋权
if ! type ipmitool >/dev/null 2>&1 ; then
  echo "未安装ipmitool"
  result=$(grep "${username} ALL=(ALL) NOPASSWD:/bin/hostname,/bin/uname,/bin/arch,/bin/uptime,/bin/top,/bin/free,/bin/iostat,/bin/cat,/bin/df,/bin/ps,/bin/sh,/usr/bin/vmstat,/sbin/ifconfig,/bin/du,/bin/netstat,/sbin/dmidecode,/sbin/lspci,/bin/lsblk,/sbin/blkid,/bin/ipmitool,$extra_command" /etc/sudoers  |wc -l)
else
  echo "已安装ipmitool"
  ipmitool_homl=$(echo `which ipmitool`)
  result=$(grep "${username} ALL=(ALL) NOPASSWD:/bin/hostname,/bin/uname,/bin/arch,/bin/uptime,/bin/top,/bin/free,/bin/iostat,/bin/cat,/bin/df,/bin/ps,/bin/sh,/usr/bin/vmstat,/sbin/ifconfig,/bin/du,/bin/netstat,/sbin/dmidecode,/sbin/lspci,/bin/lsblk,/sbin/blkid,/bin/ipmitool,$extra_command,${ipmitool_home}" /etc/sudoers  |wc -l)
fi
  
echo $result
  
if [ $result -eq 0 ]; then
  # 备份/etc/sudoers文件
  cp /etc/sudoers /etc/sudoers_${date_time}
  # 添加sudo 权限
  echo "   " >> /etc/sudoers
  echo "## 基础平台部IT云专业网管sudo账${username}号，请勿删除" >> /etc/sudoers
  if ! type ipmitool >/dev/null 2>&1 ; then
    echo "$username ALL=(ALL) NOPASSWD:/bin/hostname,/bin/uname,/bin/arch,/bin/uptime,/bin/top,/bin/free,/bin/iostat,/bin/cat,/bin/df,/bin/ps,/bin/sh,/usr/bin/vmstat,/sbin/ifconfig,/bin/du,/bin/netstat,/sbin/dmidecode,/sbin/lspci,/bin/lsblk,/sbin/blkid,/bin/ipmitool,$extra_command" >> /etc/sudoers
  else
    ipmitool_home=$(echo `which ipmitool`)
    echo "$username ALL=(ALL) NOPASSWD:/bin/hostname,/bin/uname,/bin/arch,/bin/uptime,/bin/top,/bin/free,/bin/iostat,/bin/cat,/bin/df,/bin/ps,/bin/sh,/usr/bin/vmstat,/sbin/ifconfig,/bin/du,/bin/netstat,/sbin/dmidecode,/sbin/lspci,/bin/lsblk,/sbin/blkid,/bin/ipmitool,$extra_command,${ipmitool_home}" >> /etc/sudoers
  fi
echo "权限添加成功！"
  
else

  echo "${username}用户已赋权"

fi

# 执行完毕，删除创建用户脚本
rm -f $script_path/$script_name

                          
