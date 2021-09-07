#!/bin/bash
#*************************************************#
# 文件名：RedHat7_Security.sh                     #
# 作  者：lys4989                                 #
# 日  期：2021年07月27日                          #
# 最后修改：2021年07月29日                        #
# 功  能：RedHat7系统一键加固                     #
# 复核人：                                        #
#*************************************************#
############# 全局配置项 #############
###最大打开文件数和最大打开进程成数/etc/security/limits.conf
hard_core_value=1048576
soft_core_value=1048576
soft_nofile_value=102400
hard_nofile_value=102400
soft_nproc_value=65535
hard_nproc_value=65535

###终端超时时间
export_TMOUT=180

###/etc/systemd/system.conf
DefaultTasksMax=102400

###/etc/systemd/logind.conf
UserTasksMax=102400

#方法1：获取第一个符号的行号
#参数1：需要索引的文件名（绝对路径）.
#参数2：需要索引的符号.
function get_first_lineno_by_symbol()
{
	filename=$1
	symbol=$2
	list_lineno=`awk /^$symbol$/'{print NR}' $filename`
	arr_lineno=($list_lineno)
	first_lineno=${arr_lineno[0]}
}
#方法2：处理配置文件中的配置项
#参数1：参数code
#参数2：参数值value
function dealwith_sysctl_param()
{
	
	local check_exists=`cat /etc/sysctl.conf | grep -E "^${sysctl_param}\s*=\s*${sysctl_value}$" | wc -l`
	if [ ${check_exists} -eq 0 ];then
		local check_note=`cat /etc/sysctl.conf | grep -E "^#${sysctl_param}\s*=" | wc -l`
		local check_not_right=`cat /etc/sysctl.conf | grep -E "^${sysctl_param}\s*=" | wc -l`
		if [ ${check_note} -eq 1 ];then
			#有注释则修改注释的行#${sysctl_param}
			sed -i "s/^#${sysctl_param}\s*=.*/${sysctl_param} = ${sysctl_value}/" /etc/sysctl.conf
		elif [ ${check_not_right} -eq 1 ];then
			#如果不是参数值不对
			sed -i "s/^${sysctl_param}\s*=.*/${sysctl_param} = ${sysctl_value}/" /etc/sysctl.conf
		else
			#没有注释也没有错误配置则新增一行
			echo "${sysctl_param} = ${sysctl_value}" >> /etc/sysctl.conf
		fi
		
	fi
}
############# 加固方法 #############
function config_hosts()
{
	if [ ! -e /etc/hosts ];then
		echo "/etc/hosts does not exists, please check!" && return 1
	fi
	#获取本机eth1 网口的 ip地址.
	local eth1_ip=`ifconfig -a | grep ^eth1 -A 2 | grep inet | grep -v inet6 | awk '{print $2}' | tr -d "addr:"`
	local hostname=`hostname`
	
	local arr_ip=(${eth1_ip} "10.32.196.60" "10.32.196.61")
	local arr_hostname=(${hostname} "a500_h2" "a500_k2")
	if [ ${#arr_ip[*]} -eq ${#arr_hostname[*]} ];then
		for ((i=0;i<${#arr_ip[*]};i++))
		do
			local check_exists=`cat /etc/hosts | grep "^${arr_ip[i]}" | wc -l`
			if [ ${check_exists} -eq 0 ];then
				echo "${arr_ip[i]} ${arr_hostname[i]}" >> /etc/hosts
			fi
		done
	else
		echo "ipaddress of eth1 does not exists, please check!" && return 1
	fi
	
}
function config_ntp()
{
	if [ ! -e /etc/chrony.conf ];then
		echo "/etc/chrony.conf does not exists, please check!" && return 1
	fi
	#修改timezone
	timedatectl set-timezone Asia/Shanghai
	if [ $? -ne 0 ];then
		echo "timedatectl set-timezone Asia/Shanghai failed." && return 1
	fi
	#打开ntp
	timedatectl set-ntp true
	if [ $? -ne 0 ];then
		echo "timedatectl set-ntp true failed." && return 1
	fi
	
	#配置ntp server 
	local check_ntp_config1=`cat /etc/chrony.conf | grep -e "^server\s\+a500_h2$" | wc -l`
	if [ ${check_ntp_config1} -eq 0 ];then
		echo "server a500_h2" >> /etc/chrony.conf
	fi
	local check_ntp_config2=`cat /etc/chrony.conf | grep -e "^server\s\+a500_k2$" | wc -l`
	if [ ${check_ntp_config2} -eq 0 ];then
		echo "server a500_k2" >> /etc/chrony.conf
	fi
	
	systemctl restart chronyd.service > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl restart chronyd.service failed." && return 1
	fi
	systemctl enable chronyd.service > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl enable chronyd.service failed." && return 1
	fi
}
function config_runlevel()
{
	systemctl set-default multi-user.target > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl set-default multi-user.target failed." && return 1
	fi
}

function config_limits_conf()
{
	if [ ! -e /etc/security/limits.conf ];then
		echo "/etc/security/limits.conf does not exists, please check!" && return 1
	fi

	local check_hard_core=`cat /etc/security/limits.conf | grep -P "^\*\s+hard\s+core\s+\d+$" | wc -l`
	if [ ${check_hard_core} -eq 0 ];then
		echo -e "*\thard\tcore\t${hard_core_value}" >> /etc/security/limits.conf
	elif [ ${check_hard_core} -eq 1 ];then
		local cur_hard_core=`cat /etc/security/limits.conf|grep -P "^\*\s+hard\s+core\s+\d+$" | sed "s/^*\s\+hard\s\+core\s\+\([0-9]\+\)/\1/"`
		if [ ${cur_hard_core} -ne ${hard_core_value} ];then
			sed -i "s/^*\s\+hard\s\+core\s\+${cur_hard_core}/*\\thard\\tcore\\t${hard_core_value}/" /etc/security/limits.conf
		fi
	fi
	local check_soft_core=`cat /etc/security/limits.conf | grep -P "^\*\s+soft\s+core\s+\d+$" | wc -l`
	if [ ${check_soft_core} -eq 0 ];then
		echo -e "*\tsoft\tcore\t${soft_core_value}" >> /etc/security/limits.conf
	elif [ ${check_soft_core} -eq 1 ];then
		local cur_soft_core=`cat /etc/security/limits.conf | grep -P "^\*\s+soft\s+core\s+\d+$" | sed "s/^*\s\+soft\s\+core\s\+\([0-9]\+\)/\1/"`
		if [ ${cur_soft_core} -ne ${soft_core_value} ];then
			sed -i "s/^*\s\+soft\s\+core\s\+${cur_soft_core}/*\\tsoft\\tcore\\t${soft_core_value}/" /etc/security/limits.conf
		fi
	fi
	local check_soft_nofile=`cat /etc/security/limits.conf | grep -P "^\*\s+soft\s+nofile\s+\d+$" | wc -l`
	if [ ${check_soft_nofile} -eq 0 ];then
		echo -e "*\tsoft\tnofile\t${soft_nofile_value}" >> /etc/security/limits.conf
	elif [ ${check_soft_core} -eq 1 ];then
		local cur_soft_nofile=`cat /etc/security/limits.conf | grep -P "^\*\s+soft\s+nofile\s+\d+$" | sed "s/^*\s\+soft\s\+nofile\s\+\([0-9]\+\)/\1/"`
		if [ ${cur_soft_nofile} -ne ${soft_nofile_value} ];then
			sed -i "s/^*\s\+soft\s\+nofile\s\+${cur_soft_nofile}/*\\tsoft\\tnofile\\t${soft_nofile_value}/" /etc/security/limits.conf
		fi
	fi
	local check_hard_nofile=`cat /etc/security/limits.conf | grep -P "^\*\s+hard\s+nofile\s+\d+$" | wc -l`
	if [ ${check_hard_nofile} -eq 0 ];then
		echo -e "*\thard\tnofile\t${hard_nofile_value}" >> /etc/security/limits.conf
	elif [ ${check_hard_core} -eq 1 ];then
		local cur_hard_nofile=`cat /etc/security/limits.conf | grep -P "^\*\s+hard\s+nofile\s+\d+$" | sed "s/^*\s\+hard\s\+nofile\s\+\([0-9]\+\)/\1/"`
		if [ ${cur_hard_nofile} -ne ${hard_nofile_value} ];then
			sed -i "s/^*\s\+hard\s\+nofile\s\+${cur_hard_nofile}/*\\thard\\tnofile\\t${hard_nofile_value}/" /etc/security/limits.conf
		fi
	fi
	local check_soft_nproc=`cat /etc/security/limits.conf | grep -P "^\*\s+soft\s+nproc\s+\d+$" | wc -l`
	if [ ${check_soft_nproc} -eq 0 ];then
		echo -e "*\tsoft\tnproc\t${soft_nproc_value}" >> /etc/security/limits.conf
	elif [ ${check_soft_nproc} -eq 1 ];then
		local cur_soft_nproc=`cat /etc/security/limits.conf | grep -P "^\*\s+soft\s+nproc\s+\d+$" | sed "s/^*\s\+soft\s\+nproc\s\+\([0-9]\+\)/\1/"`
		if [ ${cur_soft_nproc} -ne ${soft_nproc_value} ];then
			sed -i "s/^*\s\+soft\s\+nproc\s\+${cur_soft_nproc}/*\\tsoft\\tnproc\\t${soft_nproc_value}/" /etc/security/limits.conf
		fi
	fi
	local check_hard_nproc=`cat /etc/security/limits.conf | grep -P "^\*\s+hard\s+nproc\s+\d+$" | wc -l`
	if [ ${check_hard_nproc} -eq 0 ];then
		echo -e "*\thard\tnproc\t${hard_nproc_value}" >> /etc/security/limits.conf
	elif [ ${check_hard_nproc} -eq 1 ];then
		local cur_hard_nproc=`cat /etc/security/limits.conf | grep -P "^\*\s+hard\s+nproc\s+\d+$" | sed "s/^*\s\+hard\s\+nproc\s\+\([0-9]\+\)/\1/"`
		if [ ${cur_hard_nproc} -ne ${hard_nproc_value} ];then
			sed -i "s/^*\s\+hard\s\+nproc\s\+${cur_hard_nproc}/*\\thard\\tnproc\\t${hard_nproc_value}/" /etc/security/limits.conf
		fi
	fi
	
}

function disable_service()
{
	for service in vdo.service tuned.service rhnsd.service rhsmcertd.service libstoragemgmt.service NetworkManager-wait-online.service sshd-keygen.service cpupower.service autofs.service avahi-daemon.service bluetooth.target firewalld.service dnsmasq.service dmraid-activation.service mdmonitor.service microcode.service sendmail.service postfix.service smartd.service rhnsd.service rhsmcertd.service wpa_supplicant.service
	do
		systemctl status ${service} > /dev/null 2>&1
		if [ $? -eq 4 ];then
			#服务不存在
			continue
		fi
		
		systemctl stop ${service} > /dev/null 2>&1
		if [ $? -ne 0 ];then
			echo "systemctl stop ${service} failed." && return 1
		fi
		systemctl disable ${service} > /dev/null 2>&1
		if [ $? -ne 0 ];then
			echo "systemctl disable ${service} failed." && return 1
		fi
	done
}
function create_user_group_rollback()
{
	if [ "x$1" = "xyes" ];then
		userdel -r osmgr > /dev/null 2>&1
		userdel -r toptea > /dev/null 2>&1
		userdel -r dutyview > /dev/null 2>&1
		userdel -r dutywath > /dev/null 2>&1
		groupdel osmgr > /dev/null 2>&1
		groupdel bomc > /dev/null 2>&1
		groupdel xtjgmons > /dev/null 2>&1
		
		check_return_msg=1
	fi
}
function create_user_group()
{
	local check_return_msg=0
	#回滚
	create_user_group_rollback "yes"
	#创建
	groupadd -g 1800 osmgr >> /dev/null 2>&1
	if [[ ${check_return_msg} -eq 1 && $? -ne 0 ]];then
		echo "groupadd -g 1800 osmgr failed." && return 1
	fi
	
	groupadd -g 1302 bomc  >> /dev/null 2>&1
	if [[ ${check_return_msg} -eq 1 && $? -ne 0 ]];then
		echo "groupadd -g 1302 bomc failed." && return 1
	fi
	
	groupadd -g 5000 xtjgmons >> /dev/null 2>&1
	if [[ ${check_return_msg} -eq 1 && $? -ne 0 ]];then
		echo "groupadd -g 5000 xtjgmons failed." && return 1
	fi
	
	useradd -u 1800 -g osmgr osmgr >> /dev/null 2>&1
	if [[ ${check_return_msg} -eq 1 && $? -ne 0 ]];then
		echo "useradd -u 1800 -g osmgr osmgr failed." && return 1
	fi
	
	useradd -u 1302 -g bomc -d /toptea -s /bin/bash -m toptea > /dev/null 2>&1
	if [[ ${check_return_msg} -eq 1 && $? -ne 0 ]];then
		echo "useradd -u 1302 -g bomc -d /toptea -s /bin/bash -m toptea failed." && return 1
	fi
	
	useradd -u 5000 -g xtjgmons dutyview >> /dev/null 2>&1
	if [[ ${check_return_msg} -eq 1 && $? -ne 0 ]];then
		echo "useradd -u 5000 -g xtjgmons dutyview failed." && return 1
	fi
	
	useradd -u 5001 -g xtjgmons dutywath  >> /dev/null 2>&1
	if [[ ${check_return_msg} -eq 1 && $? -ne 0 ]];then
		echo "useradd -u 5001 -g xtjgmons dutywath failed." && return 1
	fi
	
	cp /etc/skel/.bash* /toptea/ > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "cp /etc/skel/.bash* /toptea/ failed." && return 1
	fi
	
	chown -R toptea:bomc /toptea/ > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "chown -R toptea:bomc /toptea/ failed." && return 1
	fi
	
	local check_sudoers_dutyview=`cat /etc/sudoers | grep -E "^dutyview\s*ALL=\(ALL\)\s+NOPASSWD:\s*/usr/sbin/\*,\s*/usr/bin/\*,\s*\!/usr/sbin/su" | wc -l`
	if [ ${check_sudoers_dutyview} -eq 0 ];then
		sed -i '$a\dutyview ALL=(ALL) NOPASSWD: /usr/sbin/*, /usr/bin/*, !/usr/sbin/su' /etc/sudoers
	fi
	
	local check_sudoers_dutywath=`cat /etc/sudoers | grep -E "^dutywath\s*ALL=\(ALL\)\s+NOPASSWD:\s*/usr/sbin/\*,\s*/usr/bin/\*,\s*\!/usr/sbin/su" | wc -l`
	if [ ${check_sudoers_dutywath} -eq 0 ];then
		sed -i '$a\dutywath ALL=(ALL) NOPASSWD: /usr/sbin/*, /usr/bin/*, !/usr/sbin/su' /etc/sudoers
	fi
	
	local check_Defaults_logfile=`cat /etc/sudoers | grep -e "^Defaults\s\+logfile=/var/log/sudo.log" | wc -l`
	if [ ${check_Defaults_logfile} -eq 0 ];then
		sed -i '$a Defaults\tlogfile=/var/log/sudo.log' /etc/sudoers
	fi
}
function config_passwd_complex()
{
	if [ ! -e /etc/pam.d/passwd ];then
		echo "/etc/pam.d/passwd does not exists, please check!" && return 1
	fi
	#配置密码复杂度策略
	
	check1=`cat /etc/pam.d/passwd | grep ^password | grep requisite | grep pam_cracklib.so | grep minlen=8 | grep ucredit=-1 | grep lcredit=-1 | grep dcredit=-1 | wc -l`
	if [ ${check1} -eq 0 ];then
		echo -e "password requisite pam_cracklib.so minlen=8 ucredit=-1 lcredit=-1 dcredit=-1" >> /etc/pam.d/passwd
	fi
	check2=`cat /etc/pam.d/passwd | grep ^password | grep required | grep pam_unix.so | grep remember=5 | grep "use_authtok md5 shadow" | wc -l`
	if [ ${check2} -eq 0 ];then
		echo -e "password required pam_unix.so remember=5 use_authtok md5 shadow" >> /etc/pam.d/passwd
	fi
	
}
#禁止除root，osmgr外的用户使用su
function disable_su()
{
	if [[ ! -e /etc/pam.d/su || ! -e /etc/login.defs ]];then
		echo "/etc/pam.d/su or /etc/login.defs does not exists, please check!" && return 1
	fi
	
	local check_exists=`cat /etc/pam.d/su | grep -E "^\s*auth\s+required\s+pam_wheel.so\s+use_uid$" | wc -l`
	if [ ${check_exists} -eq 0 ];then
		#检查是否被注释
		local check_note=`cat /etc/pam.d/su | grep -E "^#+\s*auth\s+required\s+pam_wheel.so\s+use_uid\s*$" | wc -l`
		if [ ${check_note} -ge 1 ];then
			sed -i "s/^#\+\s*auth\s\+required\s\+pam_wheel.so\s\+use_uid\s*$/auth\trequired\tpam_wheel.so use_uid/" /etc/pam.d/su
		else
			echo -e "auth\trequired\tpam_wheel.so use_uid" /etc/pam.d/su
		fi
		
	fi
	
	local check_exists=`cat /etc/login.defs | grep -E "^\s*SU_WHEEL_ONLY\s+yes$" | wc -l`
	if [ ${check_exists} -eq 0 ];then
		#检查是否被注释
		local check_note=`cat /etc/login.defs | grep -E "^#+\s*SU_WHEEL_ONLY\s+.*" | wc -l`
		if [ ${check_note} -ge 1 ];then
			sed -i "s/^#\+\s*SU_WHEEL_ONLY\s\+.*/SU_WHEEL_ONLY yes/" /etc/login.defs
		else
			echo "SU_WHEEL_ONLY yes" >> /etc/login.defs
		fi
	fi
	
	usermod -aG wheel osmgr
	if [ $? -ne 0 ];then
		echo "usermod -aG wheel osmgr failed." && return 1
	fi
}
function modity_user_passwd()
{
	for user in root osmgr dutyview dutywath
	do
		echo "$user":FGctD7w6|chpasswd > /dev/null 2>&1
	done
}

function config_passwd_exp_time()
{
	#Password expiration time 90 day
	for user in root osmgr
	do	
		chage -M 90 ${user}
		if [ $? -ne 0 ];then
			echo "chage -M 90 ${user} failed." && return 1
		fi
	done
	#Password expiration time before 7 day
	for user in root osmgr dutyview dutywath
	do
		chage -W 7 ${user}
		if [ $? -ne 0 ];then
			echo "chage -W 7 ${user} failed." && return 1
		fi
	done
	
}

function disable_anonymous_vsftp()
{
	if [ -e /etc/vsftpd/vsftpd.conf ]; then
		sed -i 's/anonymous_enable=YES/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf > /dev/null 2>&1
		local check_exists=`cat /etc/vsftpd/vsftpd.conf | grep -iE "^\s*anonymous_enable\s*=\s*NO\s*$" | wc -l`
		if [ ${check_exists} -eq 0 ];then
			#检查是否被注释
			local check_note=`cat /etc/vsftpd/vsftpd.conf | grep -iE "^#+\s*anonymous_enable\s*=.*" | wc -l`
			if [ ${check_note} -ge 1 ];then
				sed -i "s/^#\+\s*anonymous_enable\s*=.*/anonymous_enable=NO/i" /etc/vsftpd/vsftpd.conf
			else
				echo "anonymous_enable=NO" >> /etc/vsftpd/vsftpd.conf
			fi
		fi
		systemctl enable vsftpd.service > /dev/null 2>&1
		if [ $? -ne 0 ];then
			echo "systemctl enable vsftpd.service failed." && return 1
		fi
		
		systemctl restart vsftpd.service > /dev/null 2>&1
		if [ $? -ne 0 ];then
			echo "systemctl restart vsftpd.service failed." && return 1
		fi
	fi
	
	
}

function config_term_timeout()
{
	if [ ! -e /etc/profile ];then
		echo "/etc/profile does not exists, please check!" && return 1
	fi
	local check_TMOUT=`cat /etc/profile | grep -i "^export TMOUT=${export_TMOUT}$" | wc -l`
	if [ ${check_TMOUT} -eq 0 ];then
		local check_note=`cat /etc/profile | grep -i "^#export TMOUT=" | wc -l`
		local check_not_right=`cat /etc/profile | grep -i "^export TMOUT=" | wc -l`
		
		if [ ${check_note} -eq 1 ];then
			#有注释则修改注释的行#export TMOUT=
			sed -i "s/^#export TMOUT=.*/export TMOUT=${export_TMOUT}/i" /etc/profile
		elif [ ${check_not_right} -eq 1 ];then
			#文件中TMOUT参数值不对
			sed -i "s/^export TMOUT=.*/export TMOUT=${export_TMOUT}/i" /etc/profile
		else
			#没有注释也不是参数值不对则新增一行
			echo "export TMOUT=${export_TMOUT}" >> /etc/profile
		fi
	fi
}
function get_first_lineno_by_symbol()
{
	filename=$1
	symbol=$2
	list_lineno=`awk /^$symbol$/'{print NR}' $filename`
	arr_lineno=($list_lineno)
	first_lineno=${arr_lineno[0]}
}
function config_syslog()
{
	if [[ ! -e /etc/rsyslog.conf || ! -e /etc/logrotate.d/syslog ]];then
		echo "/etc/profile does not exists, please check!" && return 1
	fi
	local check_exists=`cat /etc/rsyslog.conf | grep -E "^\s*kern\s*,\s*daemon.err\s+/var/log/err.log\s*$" | wc -l`
	if [ ${check_exists} -eq 0 ];then
		#检查是否被注释
		local check_note=`cat /etc/rsyslog.conf | grep -E "^#+\s*kern\s*,\s*daemon.err\s+/var/log/err.log\s*$" | wc -l`
		if [ ${check_note} -ge 1 ];then
			sed -i "s/^#\+\s*kern\s*,\s*daemon.err\s\+\/var\/log\/err.log\s*$/kern,daemon.err\t\t\t\t\t\t\t\t\/var\/log\/err.log/" /etc/rsyslog.conf
		else
			sed -i '$a # Save err log\nkern,daemon.err\t\t\t\t\t\t\t\t/var/log/err.log' /etc/rsyslog.conf
		fi
	fi
	local check_exists=`cat /etc/logrotate.d/syslog | grep -E "^\s*/var/log/err.log\s*$" | wc -l`
	if [ ${check_exists} -eq 0 ];then
		#检查是否被注释
		local check_note=`cat /etc/logrotate.d/syslog | grep -E "^#+\s*/var/log/err.log\s*$" | wc -l`
		if [ ${check_note} -ge 1 ];then
			sed -i "s/^#\+\s*\/var\/log\/err.log\s*$/\/var\/log\/err.log/" /etc/logrotate.d/syslog
		else
			get_first_lineno_by_symbol "/etc/logrotate.d/syslog" "{"
			sed -i "${first_lineno}i /var/log/err.log" /etc/logrotate.d/syslog
		fi
	fi
	
	systemctl restart rsyslog.service > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl restart rsyslog.service failed." && return 1
	fi
}
function config_kdump()
{
	systemctl enable kdump.service > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl enable kdump failed." && return 1
	fi
	
	systemctl start kdump.service > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl start kdump failed." && return 1
	fi
	
}
function disable_se_linux()
{
	if [ ! -e /etc/selinux/config ];then
		echo "/etc/selinux/config does not exists, please check!" && return 1
	fi
	local check_exists=`cat /etc/selinux/config | grep -iE "^\s*SELINUX\s*=\s*disabled\s*$" | wc -l`
	if [ ${check_exists} -eq 0 ];then
		#检查是否被注释
		local check_note=`cat /etc/selinux/config | grep -iE "^#+\s*SELINUX\s*=.*" | wc -l`
		local check_right=`cat /etc/selinux/config | grep -iE "^\s*SELINUX\s*=.*" | wc -l`
		if [ ${check_note} -ge 1 ];then
			sed -i "s/^#\+\s*SELINUX\s*=.*/SELINUX=disabled/i" /etc/selinux/config
		elif [ ${check_right} -ge 1 ];then
			sed -i "s/^\s*SELINUX\s*=.*/SELINUX=disabled/i" /etc/selinux/config
		else
			echo "SELINUX=disabled" >> /etc/selinux/config
		fi
	fi
}

function config_sysctl()
{
	rm -f /etc/sysctl_conf.temp
	#系统内核参数，EOF中的内容可自行修改	/etc/sysctl.conf
	#先写入一个临时文件
	cat << EOF >> /etc/sysctl_conf.temp
net.core.netdev_budget=600
net.core.netdev_max_backlog=65536
net.core.optmem_max=536870912
net.core.rmem_default=106954752
net.core.rmem_max=536870912
net.core.somaxconn=60000
net.core.wmem_default=106954752
net.core.wmem_max=536870912
net.ipv4.ip_local_port_range=32768 61000
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_frto=0
net.ipv4.tcp_keepalive_intvl=75
net.ipv4.tcp_low_latency=0
net.ipv4.tcp_max_syn_backlog=60000
net.ipv4.tcp_max_tw_buckets=180000
net.ipv4.tcp_mem=106954752 106954752 536870912
net.ipv4.tcp_retries2=8
net.ipv4.tcp_rmem=106954752 106954752 536870912
net.ipv4.tcp_sack=0
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_tw_recycle=0
net.ipv4.tcp_tw_reuse=0
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_wmem=106954752 106954752 536870912
vm.extra_free_kbytes=5242880
vm.swappiness=10
vm.zone_reclaim_mode=0
EOF
	cat /etc/sysctl_conf.temp | while read line
	do
		local sysctl_param=`echo $line | awk -F'=' '{gsub(/^\s+|\s+$/,"",$1);print $1}'`
		local sysctl_value=`echo $line | awk -F'=' '{gsub(/^\s+|\s+$/,"",$2);print $2}'`
		#local param_value=${param}" = "${value}
		dealwith_sysctl_param
	done
	rm -f /etc/sysctl_conf.temp
}
function config_TasksMax()
{
	if [[ ! -e /etc/systemd/system.conf || ! -e /etc/systemd/logind.conf ]];then
		echo "/etc/systemd/system.conf or /etc/systemd/logind.conf does not exists, please check!" && return 1
	fi
	local check_DefaultTasksMax_exists=`cat /etc/systemd/system.conf | grep -i "^DefaultTasksMax=${DefaultTasksMax}$" | wc -l`
	if [ ${check_DefaultTasksMax_exists} -eq 0 ];then
		local check_note=`cat /etc/systemd/system.conf | grep -i "^#DefaultTasksMax=" | wc -l`
		local check_not_right=`cat /etc/systemd/system.conf | grep -i "^DefaultTasksMax=" | wc -l`
		
		if [ ${check_note} -eq 1 ];then
			#有注释则修改注释的行#DefaultTasksMax=
			sed -i "s/^#DefaultTasksMax=.*/DefaultTasksMax=${DefaultTasksMax}/i" /etc/systemd/system.conf
		elif [ ${check_not_right} -eq 1 ];then
			#文件中DefaultTasksMax参数值不对
			sed -i "s/^DefaultTasksMax=.*/DefaultTasksMax=${DefaultTasksMax}/i" /etc/systemd/system.conf
		else
			#没有注释也不是参数值不对则新增一行
			echo "DefaultTasksMax=${DefaultTasksMax}" >> /etc/systemd/system.conf
		fi
	fi
	local check_UserTasksMax_exists=`cat /etc/systemd/logind.conf | grep -i "^UserTasksMax=${UserTasksMax}$" | wc -l`
	if [ ${check_UserTasksMax_exists} -eq 0 ];then
		local check_note=`cat /etc/systemd/logind.conf | grep -i "^#UserTasksMax=" | wc -l`
		local check_not_right=`cat /etc/systemd/logind.conf | grep -i "^UserTasksMax=" | wc -l`
		
		if [ ${check_note} -eq 1 ];then
			#有注释则修改注释的行#UserTasksMax=
			sed -i "s/^#UserTasksMax=.*/UserTasksMax=${UserTasksMax}/i" /etc/systemd/logind.conf
		elif [ ${check_not_right} -eq 1 ];then
			#文件中UserTasksMax参数值不对
			sed -i "s/^UserTasksMax=.*/UserTasksMax=${UserTasksMax}/i" /etc/systemd/logind.conf
		else
			#没有注释也不是参数值不对则新增一行
			echo "UserTasksMax=${UserTasksMax}" >> /etc/systemd/logind.conf
		fi
	fi
	
	systemctl daemon-reexec
	if [ $? -ne 0 ];then
		echo "systemctl daemon-reexec failed." && return 1
	fi
}
function main()
{
	config_hosts
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	config_ntp
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	config_runlevel
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	config_limits_conf
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	disable_service
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	create_user_group
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	config_passwd_complex
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	disable_su
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	modity_user_passwd
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	config_passwd_exp_time
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	disable_anonymous_vsftp
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	config_term_timeout
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	config_syslog
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	config_kdump
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	disable_se_linux
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	config_sysctl
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
	
	config_TasksMax
	if [ $? -ne 0 ];then
		echo "DO RedHat7_Security failed." && exit 1
	fi
}
main