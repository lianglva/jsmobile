#!/bin/bash
#*************************************************#
# 文件名：SUSE12_Security.sh                      #
# 作  者：lys4989                                 #
# 日  期：2021年07月23日                          #
# 最后修改：2021年07月28日                        #
# 功  能：SUSE12系统一键加固                      #
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

###/etc/systemd/system.conf
DefaultTasksMax=102400

###/etc/systemd/logind.conf
UserTasksMax=102400

###终端超时时间
export_TMOUT=180

###umask值设定
umask=027

############# 公共方法 #############
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
#方法2：获取最后一个符号的行号
#参数1：需要索引的文件名（绝对路径）.
#参数2：需要索引的符号.
function get_last_lineno_by_symbol()
{
	filename=$1
	symbol=$2
	list_lineno=`awk /^$symbol$/'{print NR}' $filename`
	arr_lineno=($list_lineno)
	((max_arr_index=${#arr_lineno[@]} - 1))
	last_lineno=${arr_lineno[$max_arr_index]}
}
#方法3：处理配置文件中的配置项
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
function config_after_local()
{
	if [ ! -e /etc/init.d/after.local ];then
		echo "/etc/init.d/after.local does not exists, please check!" && return 1
	fi
	local check_exists=`cat /etc/init.d/after.local | grep "^mount -a" | wc -l`
	if [ ${check_exists} -eq 0 ];then
		echo -e '\nmount -a' >> /etc/init.d/after.local
	fi
	#赋执行权限
	chmod u+x /etc/init.d/after.local
	if [ $? -ne 0 ];then
		echo "chmod u+x /etc/init.d/after.local failed." && return 1
	fi
}
function disable_anonymous_vsftp()
{
	if [ ! -e /etc/vsftpd.conf ];then
		echo "/etc/vsftpd.conf does not exists, please check!" && return 1
	fi
	#检查文件配置.
	local check_enable=`cat /etc/vsftpd.conf | grep "^anonymous_enable=YES" | wc -l`
	local check_disable=`cat /etc/vsftpd.conf | grep "^anonymous_enable=NO" | wc -l`
	if [ ${check_disable} -eq 1 ];then
		usleep
	fi
	if [ ${check_enable} -eq 1 ];then
		sed -i 's/anonymous_enable=YES/anonymous_enable=NO/' /etc/vsftpd.conf
		if [ $? -ne 0 ];then
			echo "sed -i 's/anonymous_enable=YES/anonymous_enable=NO/' /etc/vsftpd.conf failed." && return 1
		fi
	fi
	
	systemctl restart vsftpd >> /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl restart vsftpd failed." && return 1
	fi
	
	systemctl enable vsftpd >> /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl enable vsftpd failed." && return 1
	fi
}
function disable_feedback_version()
{
	if [[ ! -e /etc/issue || ! -e /etc/issue.net ]];then
		echo "/etc/issue or /etc/issue.net does not exists, please check!" && return 1
	fi
	#防止重复备份后文件为空
	if [ ! -e /etc/issue-bak ];then
		cp /etc/issue /etc/issue-bak
		:>/etc/issue
	fi
	if [ ! -e /etc/issue-net-bak ];then
		cp /etc/issue.net /etc/issue-net-bak
		:>/etc/issue.net
	fi
	
}
function change_file_mode_bits()
{
	if [[ ! -e /etc/passwd || ! -e /etc/group || ! -e /etc/shadow ]];then
		echo "/etc/passwd or /etc/group or /etc/shadow does not exists, please check!" && return 1
	fi
	chmod 644 /etc/passwd
	if [ $? -ne 0 ];then
		echo "chmod 644 /etc/passwd failed." && return 1
	fi
	
	chmod 644 /etc/group
	if [ $? -ne 0 ];then
		echo "chmod 644 /etc/group failed." && return 1
	fi
	
	chmod 400 /etc/shadow
	if [ $? -ne 0 ];then
		echo "chmod 400 /etc/shadow failed." && return 1
	fi
	
}
function config_kdump()
{
	if [ ! -e /etc/sysconfig/kdump ];then
		echo "/etc/sysconfig/kdump does not exists, please check!" && return 1
	fi
	local check_kdump_cfg=`cat /etc/sysconfig/kdump | grep "^KDUMP_SAVEDIR=" | grep "/var/crash" | wc -l`
	if [ ${check_kdump_cfg} -eq 1 ];then
		usleep
	else
		echo -e "\nKDUMP_SAVEDIR=file:///var/crash" >> /etc/sysconfig/kdump
	fi
	
	systemctl enable kdump >> /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl enable kdump failed." && return 1
	fi
	
	systemctl start kdump >> /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl start kdump failed." && return 1
	fi
	
}
function config_hosts_allow()
{
	if [ ! -e /etc/hosts.allow ];then
		echo "/etc/hosts.allow does not exists, please check!" && return 1
	fi
	#不能重复添加配置
	local check_exists=`cat /etc/hosts.allow | grep -E "^sshd\s*:\s*10\.32[^0-9]*:\s*(ALLOW|allow)" | wc -l`
	if [ ${check_exists} -le 0 ];then
		echo "sshd:10.32.*.*:allow" >> /etc/hosts.allow
	fi
	local check_exists=`cat /etc/hosts.allow | grep -E "^sshd\s*:\s*10\.33[^0-9]*:\s*(ALLOW|allow)" | wc -l`
	if [ ${check_exists} -le 0 ];then
		echo "sshd:10.33.*.*:allow" >> /etc/hosts.allow
	fi
	local check_exists=`cat /etc/hosts.allow | grep -E "^sshd\s*:\s*190\.168[^0-9]*:\s*(ALLOW|allow)" | wc -l`
	if [ ${check_exists} -le 0 ];then
		echo "sshd:190.168.*.*:allow" >> /etc/hosts.allow
	fi
	local check_exists=`cat /etc/hosts.allow | grep -E "^sshd\s*:\s*192\.168[^0-9]*:\s*(ALLOW|allow)" | wc -l`
	if [ ${check_exists} -le 0 ];then
		echo "sshd:192.168.*.*:allow" >> /etc/hosts.allow
	fi
	
}
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
function config_runlevel()
{
	systemctl set-default multi-user.target > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl set-default multi-user.target failed." && return 1
	fi
}
function config_ntp()
{
	if [[ ! -e /etc/sysconfig/clock || ! -e /etc/ntp.conf ]];then
		echo "/etc/sysconfig/clock or /etc/ntp.conf does not exists, please check!" && return 1
	fi
	#修改timezone
	local check_time_zone=`cat /etc/sysconfig/clock | grep -i ^timezone | grep "Asia/Shanghai" | wc -l`
	if [ ${check_time_zone} -eq 0 ];then
		sed -i 's/^timezone=.*/TIMEZONE="Asia\/Shanghai"/i' /etc/sysconfig/clock
	fi
	#配置ntp server 
	local check_ntp_config1=`cat /etc/ntp.conf | grep -e "^server\s\+a500_h2$" | wc -l`
	if [ ${check_ntp_config1} -eq 0 ];then
		echo "server a500_h2" >> /etc/ntp.conf
	fi
	local check_ntp_config2=`cat /etc/ntp.conf | grep -e "^server\s\+a500_k2$" | wc -l`
	if [ ${check_ntp_config2} -eq 0 ];then
		echo "server a500_k2" >> /etc/ntp.conf
	fi
	
	systemctl enable ntpd > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl enable ntpd failed." && return 1
	fi
	systemctl start ntpd > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl start ntpd failed." && return 1
	fi
}
function config_passwd_complex()
{
	if [[ ! -e /etc/pam.d/common-password || ! -e /etc/pam.d/su || ! -e /etc/pam.d/su-l ]];then
		echo "/etc/pam.d/common-password or /etc/pam.d/su or /etc/pam.d/su-l does not exists, please check!" && return 1
	fi
	#配置密码复杂度策略
	check1=`cat /etc/pam.d/common-password | grep ^Password | grep requisite | grep pam_cracklib.so | grep minlen=8 | grep ucredit=-1 | grep lcredit=-1 | grep dcredit=-1 | wc -l`
	if [ ${check1} -eq 0 ];then
		echo -e 'Password requisite pam_cracklib.so ucredit=-1 lcredit=-1 dcredit=-1 minlen=8' >> /etc/pam.d/common-password
	fi
	check2=`cat /etc/pam.d/common-password | grep ^Password | grep required | grep pam_unix.so | grep remember=5 | grep use_authtok | grep nullok | grep shadow | grep try_first_pass | wc -l`
	if [ ${check2} -eq 0 ];then
		echo -e 'Password required pam_unix.so use_authtok nullok shadow try_first_pass remember=5' >> /etc/pam.d/common-password
	fi
	#禁止除root，osmgr外的用户使用su
	check_pam_su=`cat /etc/pam.d/su | grep ^auth | grep required | grep "pam_wheel.so" | grep "group=wheel$" | wc -l`
	if [ ${check_pam_su} -eq 0 ];then
		list_line=`awk /^auth/'{print NR}' /etc/pam.d/su`
		arr_line=(${list_line})
		((max_index=${#arr_line[@]} - 1))
		local insert_num=${arr_line[$max_index]}
		sed -i "${insert_num}a auth required pam_wheel.so group=wheel" /etc/pam.d/su
	fi
	
	local check_su_l=`cat /etc/pam.d/su-l | grep "^auth" | grep required | grep pam_wheel.so | grep group=wheel | wc -l`
	if [ ${check_su_l} -eq 0 ];then
		echo "auth required pam_wheel.so group=wheel" >> /etc/pam.d/su-l
	fi
	
}

function config_passwd_exp_time()
{
	chage -M 90 root
	if [ $? -ne 0 ];then
		echo "chage -M 90 root failed." && return 1
	fi
	chage -M 90 osmgr
	if [ $? -ne 0 ];then
		echo "chage -M 90 osmgr failed." && return 1
	fi
	chage -W 7 root
	if [ $? -ne 0 ];then
		echo "chage -W 7 root failed." && return 1
	fi
	chage -W 7 osmgr
	if [ $? -ne 0 ];then
		echo "chage -W 7 osmgr failed." && return 1
	fi
	chage -W 7 dutyview
	if [ $? -ne 0 ];then
		echo "chage -W 7 dutyview failed." && return 1
	fi
	chage -W 7 dutywath
	if [ $? -ne 0 ];then
		echo "chage -W 7 dutywath failed." && return 1
	fi
	chage -m 0 root
	if [ $? -ne 0 ];then
		echo "chage -m 0 root failed." && return 1
	fi
}
function config_sar()
{
	#需要完善
	systemctl start sysstat > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl start sysstat failed." && return 1
	fi
	
	systemctl enable sysstat > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl enable sysstat failed." && return 1
	fi
}
function disable_service()
{
	for service in xinetd.service ypbind.service nfs-client.target nfsserver.service nfs.service bluetooth.service SuSEfirewall2.service SuSEfirewall2_setup.service SuSEfirewall2_init.service postfix.service nmb.service smb.service nfsserver.service mdmonitor.service cpus-browed.service cups.service avahi-daemon.socket avahi-dnsconfd.service avahi-daemon.service autofs.service
	do
		is_exists=`systemctl status ${service%.*} | grep "not-found" | wc -l`
		if [ ${is_exists} -eq 1 ];then
			#服务不存在
			#echo "${service%.*} not exists."
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
function config_ssh_security()
{
	if [ ! -e /etc/ssh/sshd_config ];then
		echo "/etc/ssh/sshd_config does not exists, please check!" && return 1
	fi
	local check_permit_root_login=`cat /etc/ssh/sshd_config | grep -i "^PermitRootLogin yes$" | wc -l`
	if [ ${check_permit_root_login} -eq 0 ];then
		local check_note=`cat /etc/ssh/sshd_config | grep -i "^#PermitRootLogin " | wc -l`
		local check_not_yes=`cat /etc/ssh/sshd_config | grep -i "^PermitRootLogin " | wc -l`
		
		if [ ${check_note} -eq 1 ];then
			#有注释则修改注释的行#PermitRootLogin 
			sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/i' /etc/ssh/sshd_config
		elif [ ${check_not_yes} -eq 1 ];then
			#文件中如果不是PermitRootLogin yes
			sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/i' /etc/ssh/sshd_config
		else
			#没有注释也没有错误配置则新增一行
			echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
		fi
		
	fi
	
	local check_passwd_auth=`cat /etc/ssh/sshd_config | grep -i "^PasswordAuthentication yes$" | wc -l`
	if [ ${check_passwd_auth} -eq 0 ];then
		local check_note=`cat /etc/ssh/sshd_config | grep -i "^#PasswordAuthentication " | wc -l`
		local check_not_yes=`cat /etc/ssh/sshd_config | grep -i "^PasswordAuthentication " | wc -l`
		
		if [ ${check_note} -eq 1 ];then
			#有注释则修改注释的行#PasswordAuthentication 
			sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/i' /etc/ssh/sshd_config
		elif [ ${check_not_yes} -eq 1 ];then
			#文件中如果不是PasswordAuthentication yes
			sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/i' /etc/ssh/sshd_config
		else
			#没有注释也没有错误配置则新增一行
			echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
		fi
		
	fi
	
	local check_protocol=`cat /etc/ssh/sshd_config | grep -i "^Protocol 2$" | wc -l`
	if [ ${check_protocol} -eq 0 ];then
		local check_note=`cat /etc/ssh/sshd_config | grep -i "^#Protocol " | wc -l`
		local check_not_2=`cat /etc/ssh/sshd_config | grep -i "^Protocol " | wc -l`
		
		if [ ${check_note} -eq 1 ];then
			#有注释则修改注释的行#Protocol
			sed -i 's/^#Protocol.*/Protocol 2/i' /etc/ssh/sshd_config
		elif [ ${check_not_2} -eq 1 ];then
			#文件中如果不是Protocol 2
			sed -i 's/^Protocol.*/Protocol 2/i' /etc/ssh/sshd_config
		else
			#没有注释也没有错误配置则新增一行
			echo "Protocol 2" >> /etc/ssh/sshd_config
		fi
		
	fi
	
	systemctl restart sshd >> /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl restart sshd failed." && return 1
	fi
	systemctl enable sshd >> /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "systemctl enable sshd failed." && return 1
	fi
}
function backup_sysctl()
{
	if [ -e /etc/sysctl-install.bak ];then
		return 0
	fi
	sysctl -a >> /etc/sysctl-install.bak
	if [ $? -ne 0 ];then
		echo "sysctl -a failed." && return 1
	fi
}

function config_sysctl()
{
	rm -f /etc/sysctl_conf.temp
	#系统内核参数，EOF中的内容可自行修改	/etc/sysctl.conf
	#先写入一个临时文件
	cat << EOF >> /etc/sysctl_conf.temp
net.ipv6.conf.all.forwarding = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.rp_filter = 1
fs.inotify.max_user_watches = 2000000
net.ipv4.conf.default.promote_secondaries = 1
net.ipv4.conf.all.promote_secondaries = 1
kernel.pid_max = 131072
kernel.threads-max = 1547035
kernel.shmmax = 6589934592
kernel.shmall = 12582912
kernel.shmmni = 4096
kernel.msgmax = 1048576
kernel.msgmnb = 4194304
kernel.msgmni = 6000
kernel.core_pattern = /corefiles/core.%p.%e
kernel.sem = 1250 320000 100 256
fs.file-max = 2000000
net.ipv4.ip_local_port_range = 26000 39999
net.core.rmem_default = 8388608
net.core.rmem_max = 8388608
net.core.wmem_default = 8388608
net.core.wmem_max = 20971520
vm.min_free_kbytes = 5000000
vm.swappiness = 5
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
kernel.suid_dumpable = 2
vm.max_map_count = 655360
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
function config_syslog()
{
	if [[ ! -e /etc/rsyslog.conf || ! -e /etc/logrotate.d/syslog ]];then
		echo "/etc/rsyslog.conf or /etc/logrotate.d/syslog does not exists, please check!" && return 1
	fi
	
	local check_log1=`cat /etc/rsyslog.conf | grep -E "^\*\.err\s+/var/log/errors$" | wc -l`
	if [ ${check_log1} -eq 0 ];then
		echo -e "*.err\t/var/log/errors" >> /etc/rsyslog.conf
	fi
	local check_log2=`cat /etc/rsyslog.conf | grep -E "^authpriv\.\*\s+/var/log/authpriv_info$" | wc -l`
	if [ ${check_log2} -eq 0 ];then
		echo -e "authpriv.*\t/var/log/authpriv_info" >> /etc/rsyslog.conf
	fi
	local check_log3=`cat /etc/rsyslog.conf | grep -E "^authpriv\.\*\s+/var/log/secure$" | wc -l`
	if [ ${check_log3} -eq 0 ];then
		echo -e "authpriv.*\t/var/log/secure" >> /etc/rsyslog.conf
	fi
	local check_log4=`cat /etc/rsyslog.conf | grep -E "^\*\.info\s+/var/log/info$" | wc -l`
	if [ ${check_log4} -eq 0 ];then
		echo -e "*.info\t/var/log/info" >> /etc/rsyslog.conf
	fi
	local check_log5=`cat /etc/rsyslog.conf | grep -E "^cron\.\*\s+/var/log/cron$" | wc -l`
	if [ ${check_log5} -eq 0 ];then
		echo -e "cron.*\t/var/log/cron" >> /etc/rsyslog.conf
	fi
	local check_log6=`cat /etc/rsyslog.conf | grep -E "^auth\.\*\s+/var/log/auth_none$" | wc -l`
	if [ ${check_log6} -eq 0 ];then
		echo -e "auth.*\t/var/log/auth_none" >> /etc/rsyslog.conf
	fi
	local check_log7=`cat /etc/rsyslog.conf | grep -E "^\*\.err\s+/toptea/errors$" | wc -l`
	if [ ${check_log7} -eq 0 ];then
		echo -e "*.err\t/toptea/errors" >> /etc/rsyslog.conf
	fi
	
	local first_lineno=0
	
	local check_var_log1=`cat /etc/logrotate.d/syslog | grep "^/var/log/errors$" | wc -l`
	if [ ${check_var_log1} -eq 0 ];then
		get_first_lineno_by_symbol "/etc/logrotate.d/syslog" "{"
		sed -i "${first_lineno}i /var/log/errors" /etc/logrotate.d/syslog
	fi
	local check_var_log2=`cat /etc/logrotate.d/syslog | grep "^/var/log/authpriv_info$" | wc -l`
	if [ ${check_var_log2} -eq 0 ];then
		get_first_lineno_by_symbol "/etc/logrotate.d/syslog" "{"
		sed -i "${first_lineno}i /var/log/authpriv_info" /etc/logrotate.d/syslog
	fi
	local check_var_log3=`cat /etc/logrotate.d/syslog | grep "^/var/log/secure$" | wc -l`
	if [ ${check_var_log3} -eq 0 ];then
		get_first_lineno_by_symbol "/etc/logrotate.d/syslog" "{"
		sed -i "${first_lineno}i /var/log/secure" /etc/logrotate.d/syslog
	fi
	local check_var_log4=`cat /etc/logrotate.d/syslog | grep "^/var/log/info$" | wc -l`
	if [ ${check_var_log4} -eq 0 ];then
		get_first_lineno_by_symbol "/etc/logrotate.d/syslog" "{"
		sed -i "${first_lineno}i /var/log/info" /etc/logrotate.d/syslog
	fi
	local check_var_log5=`cat /etc/logrotate.d/syslog | grep "^/var/log/cron$" | wc -l`
	if [ ${check_var_log5} -eq 0 ];then
		get_first_lineno_by_symbol "/etc/logrotate.d/syslog" "{"
		sed -i "${first_lineno}i /var/log/cron" /etc/logrotate.d/syslog
	fi
	local check_var_log6=`cat /etc/logrotate.d/syslog | grep "^/var/log/auth_none$" | wc -l`
	if [ ${check_var_log6} -eq 0 ];then
		get_first_lineno_by_symbol "/etc/logrotate.d/syslog" "{"
		sed -i "${first_lineno}i /var/log/auth_none" /etc/logrotate.d/syslog
	fi
	#确认一下/etc/logrotate.d/toptea这个文件是不是新增的
	if [ -e /etc/logrotate.d/toptea ];then
		rm -f /etc/logrotate.d/toptea
	fi
	
	if [ ! -e /etc/logrotate.d/toptea ];then
		cat << EOF >> /etc/logrotate.d/toptea
/toptea/errors
{
    compress
    dateext
    maxage 365
    rotate 99
    missingok
    notifempty
    size +4096k
    create 640 toptea bomc
    sharedscripts
    postrotate
        /usr/bin/systemctl reload syslog.service > /dev/null
    endscript
}
EOF
	fi

	logrotate -f /etc/logrotate.conf > /dev/null 2>&1
	
	logrotate -f /etc/logrotate.d/toptea
	if [ $? -ne 0 ];then
		echo "logrotate -f /etc/logrotate.d/toptea failed." && return 1
	fi
	
	systemctl reload-or-try-restart rsyslog.service
	if [ $? -ne 0 ];then
		echo "systemctl reload-or-try-restart rsyslog.service failed." && return 1
	fi
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
function config_umask()
{
	if [ ! -e /etc/profile ];then
		echo "/etc/profile does not exists, please check!" && return 1
	fi
	local check_umask=`cat /etc/profile | grep -i "^umask ${umask}$" | wc -l`
	if [ ${check_umask} -eq 0 ];then
		local check_note=`cat /etc/profile | grep -i "^#umask " | wc -l`
		local check_not_right=`cat /etc/profile | grep -i "^umask " | wc -l`
		
		if [ ${check_note} -eq 1 ];then
			#有注释则修改注释的行#umask 
			sed -i "s/^#umask .*/umask ${umask}/i" /etc/profile
		elif [ ${check_not_right} -eq 1 ];then
			#文件中umask参数值不对
			sed -i "s/^umask .*/umask ${umask}/i" /etc/profile
		else
			#没有注释也不是参数值不对则新增一行
			echo "umask ${umask}" >> /etc/profile
		fi
	fi
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
	
	useradd -u 1800 -g osmgr -G wheel -d /home/osmgr -s /bin/bash -m osmgr >> /dev/null 2>&1
	if [[ ${check_return_msg} -eq 1 && $? -ne 0 ]];then
		echo "useradd -u 1800 -g osmgr -G wheel -d /home/osmgr -s /bin/bash -m osmgr failed." && return 1
	fi
	
	useradd -u 1302 -g bomc -d /toptea -s /bin/bash -m toptea >> /dev/null 2>&1
	if [[ ${check_return_msg} -eq 1 && $? -ne 0 ]];then
		echo "useradd -u 1302 -g bomc -d /toptea -s /bin/bash -m toptea failed." && return 1
	fi
	
	useradd -u 5000 -g xtjgmons -d /home/dutyview -s /bin/bash -m dutyview >> /dev/null 2>&1
	if [[ ${check_return_msg} -eq 1 && $? -ne 0 ]];then
		echo "useradd -u 5000 -g xtjgmons -d /home/dutyview -s /bin/bash -m dutyview failed." && return 1
	fi
	
	useradd -u 5001 -g xtjgmons -d /home/dutywath -s /bin/bash -m dutywath >> /dev/null 2>&1
	if [[ ${check_return_msg} -eq 1 && $? -ne 0 ]];then
		echo "useradd -u 5001 -g xtjgmons -d /home/dutywath -s /bin/bash -m dutywath failed." && return 1
	fi
	
	cp -ar /etc/skel/. /toptea/ >> /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "cp -ar /etc/skel/. /toptea/ failed." && return 1
	fi
	
	chown -R toptea:bomc /toptea >> /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "chown -R toptea:bomc /toptea failed." && return 1
	fi
	
	#私自增加/etc/sudoers 配置，方便后期维护
	local check_sudoers_cfg=`cat /etc/sudoers | grep -E "^dutyview\s*ALL=\(ALL\)\s+NOPASSWD:\s*/usr/sbin/\*,\s*/usr/bin/\*,\s*\!/usr/sbin/su" | wc -l`
	if [ ${check_sudoers_cfg} -eq 0 ];then
		echo 'dutyview ALL=(ALL) NOPASSWD: /usr/sbin/*, /usr/bin/*, !/usr/sbin/su'>> /etc/sudoers 
	fi
	
}

function modity_user_passwd()
{
	for user in root osmgr dutyview dutywath toptea
	do
		echo "${user}:FGctD7w6"|chpasswd >> /dev/null 2>&1
	done
	
}
function disable_default_account()
{
	for user in bin daemon lp mail news uucp games man wwwrun ftp nobody messagebus sshd polkitd nscd rpc openslp systemd-timesync systemd-bus-proxy ntp srvGeoClue at statd rtkit pulse ftpsecure vnc postfix scard gdm
	do
		local check_exists=`cat /etc/passwd | grep "^${user}:" | wc -l`
		if [ ${check_exists} -eq 1 ];then
			usermod -s /bin/false ${user} > /dev/null 2>&1
		else
			echo "user ${user} does not exists."
		fi
		
	done
}
function main()
{
	config_after_local
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	disable_anonymous_vsftp
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	disable_feedback_version
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	change_file_mode_bits
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_hosts_allow
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_hosts
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_kdump
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_limits_conf
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_runlevel
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_ntp
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	create_user_group
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_passwd_complex
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_passwd_exp_time
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_sar
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	disable_service
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_ssh_security
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	backup_sysctl
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	#配置系统内核参数，先备份backup_sysctl再修改
	config_sysctl
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_syslog
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_TasksMax
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_term_timeout
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	config_umask
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	modity_user_passwd
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
	disable_default_account
	if [ $? -ne 0 ];then
		echo "DO SUSE12_Security failed." && exit 1
	fi
	
}
main