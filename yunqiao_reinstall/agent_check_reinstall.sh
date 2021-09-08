#!/bin/bash
#******************************************* #
# 文件名：agent_check_reinstall.sh      	 #
# 作  者：lvliang                            #
# 日  期：2021年8月27日                      #
# 最后修改：2021年8月27日                    #
# 功  能：云窍IT云专业网管检查卸载安装#		 #
# 操作系统：RedHat							 #
# 复核人：                                   #
#********************************************#
script_path=/home/dutyview

function telnet_Check
{
	telnet 10.207.58.35 8888<<EOF > ${script_path}/telnet10.207.58.35.tmp
quit
EOF
	telnet 10.207.58.36 8888<<EOF > ${script_path}/telnet10.207.58.36.tmp
quit
EOF
	telnet 10.207.58.37 8888<<EOF > ${script_path}/telnet10.207.58.37.tmp
quit
EOF

	local check_telnet_suc_1=`cat ${script_path}/telnet10.207.58.35.tmp | grep "Connected to" | wc -l`
	local check_telnet_fail_1=`cat ${script_path}/telnet10.207.58.35.tmp | grep "Connection refused" | wc -l`
	local check_telnet_suc_2=`cat ${script_path}/telnet10.207.58.36.tmp | grep "Connected to" | wc -l`
	local check_telnet_fail_2=`cat ${script_path}/telnet10.207.58.36.tmp | grep "Connection refused" | wc -l`
	local check_telnet_suc_3=`cat ${script_path}/telnet10.207.58.37.tmp | grep "Connected to" | wc -l`
	local check_telnet_fail_3=`cat ${script_path}/telnet10.207.58.37.tmp | grep "Connection refused" | wc -l`
	
	rm -f ${script_path}/telnet10.207.58.35.tmp ${script_path}/telnet10.207.58.36.tmp ${script_path}/telnet10.207.58.37.tmp
	
	if [[ ${check_telnet_suc_1} -eq 1 && ${check_telnet_suc_2} -eq 1 && ${check_telnet_suc_3} -eq 1 ]];then
		#telnet success
		usleep
	fi
	if [[ ${check_telnet_fail_1} -eq 1 || ${check_telnet_fail_1} -eq 1 || ${check_telnet_fail_1} -eq 1 ]];then
		#telnet fail && check route
		local check_route=`route -n | grep "10.207.58.0" | wc -l`
		if [ ${check_route} -eq 0 ];then
			#添加路由
			gate_way=`cat /etc/sysconfig/network-scripts/ifcfg-bond0 | grep GATEWAY | awk -F'=' '{print $2}'`
			if [ `echo ${gate_way} | grep "\." | wc -l` -eq 1 ];then
				route add -net 10.207.58.0  netmask 255.255.255.0  gw ${gate_way} dev bond0
				if [ $? -ne 0 ];then
					echo "route add temporary failed." && return 1
				fi
				echo "route add -net 10.207.58.0 netmask 255.255.255.0 gw ${gate_way} dev bond0" >> /etc/rc.d/rc.local
				if [ $? -ne 0 ];then
					echo "route add to /etc/rc.d/rc.local failed." && return 1
				fi
				chmod +x /etc/rc.d/rc.local
				if [ $? -ne 0 ];then
					echo "chmod +x /etc/rc.d/rc.local failed." && return 1
				fi
			fi
		fi
	fi
	
	
}
function remove_agent()
{
	if [ `bash ${script_path}/agent_remove.sh | grep "itcloudagent" | wc -l` -eq 1 ];then
		if [ `sh ${script_path}/agent_check.sh | wc -l` -eq 0 ];then
			echo "itcloudagent已清理干净！"
		else
			echo "agent 清理不干净，请联系王戈 17812208395" && return 1
		fi
	fi
}
function agent_check()
{
	
	if [ `sh ${script_path}/agent_check.sh | wc -l` -eq 0 ];then
		echo "no agent. --check ok"
	else
		remove_agent
		if [ $? -ne 0 ];then
			echo "remove_agent failed." && return 1
		fi
	fi
	
}
function yunqiao_user_add()
{
	bash ${script_path}/yunqiao_create.sh
	local yunqiao_exist=`id yunqiao | wc -l`
	if [ ${yunqiao_exist} -ne 1 ];then
		echo "user yunqiao create failed." && return 1
	fi
	local check_yunqiao_sudoers=`grep yunqiao /etc/sudoers | wc -l`
	if [ ${check_yunqiao_sudoers} -ne 2 ];then
		echo "grep yunqiao /etc/sudoers failed." && return 1
	fi
	
}
function prepare_for_install()
{
	#	确保18889与28889端口未被其他程序占用，agent启动之后会随机启动1个端口作为监听端口
	local port_occupied=0
	if [ `netstat -anptl |grep 18889 | wc -l` -ne 0 ];then
		echo "port 18889 has been occupied."
		port_occupied=1
	fi
		
	if [ `netstat -anptl |grep 28889 | wc -l` -ne 0 ];then
	echo "port 28889 has been occupied."
		port_occupied=1
	fi
	
	if [ ${port_occupied} -ne 0 ];then
		return 1
	fi
	
	#	检查主机当前是否已通过镜像及其他方式已部署agent，以防重复部署
	
	#	确保/opt/、/usr/local所在分区空间大于300M
	local disk_space=0
	local opt_space=`df -Th /opt | tail -n 1 | awk -F' ' '{print $5}'`
	if [ "x${opt_space}" = "x" ];then
		echo "no /opt ,failed" && return 1
	fi
	if [ `echo ${opt_space} | grep G | wc -l` -eq 1 ];then
		usleep
	elif [ `echo ${opt_space} | grep M | wc -l` -eq 1 ];then
		local opt_space_M=`echo ${opt_space} | awk -F'M' '{print $1}'`
		if [ ${opt_space_M} -le 300 ];then
			echo "available space of /opt <= 300M ,failed."
			disk_space=1
		fi
	else
		echo "available space of /opt <= 300M ,failed."
		disk_space=1
	fi
	
	local usr_local_space=`df -Th /usr/local | tail -n 1 | awk -F' ' '{print $5}'`
	if [ "x${usr_local_space}" = "x" ];then
		echo "no /usr/local ,failed" && return 1
	fi
	if [ `echo ${usr_local_space} | grep G | wc -l` -eq 1 ];then
		usleep
	elif [ `echo ${usr_local_space} | grep M | wc -l` -eq 1 ];then
		local usr_local_space_M=`echo ${usr_local_space} | awk -F'M' '{print $1}'`
		if [ ${usr_local_space_M} -le 300 ];then
			echo "available space of /usr/local <= 300M ,failed."
			disk_space=1
		fi
	else
		echo "available space of /usr/local <= 300M ,failed."
		disk_space=1
	fi
	
	if [ ${disk_space} -ne 0 ];then
		return 1
	fi
	
}
function do_install()
{
	su - yunqiao -c "curl -Ssl http://10.207.58.35:8888/api/download/initClientScript | bash -s itcloudagent"
	su - yunqiao -c "curl -Ssl http://10.207.58.36:8888/api/download/initClientScript | bash -s itcloudagent"
	su - yunqiao -c "curl -Ssl http://10.207.58.37:8888/api/download/initClientScript | bash -s itcloudagent"
	
}
function check_after_install()
{
	#1,检查agent是否正常启动，会运行一个version_check程序与一个itcloudagent程序
	if [ `ps aux |grep itcloud |grep agent | wc -l` -ne 2 ];then
		echo "ps aux |grep itcloud |grep agent --check failed." && return 1
	fi
	
	#2,检查18889或28889端口是否正常启动
	if [[ `netstat -nptl |grep 18889 | wc -l` -gt 0 || `netstat -nptl |grep 28889 | wc -l` -gt 0 ]];then
		usleep
	else
		echo "netstat -nptl |grep 18889 or netstat -nptl |grep 28889 --check failed." && return 1
	fi
	
	#3,日志检查
	if [ `tail -1000 /opt/yunqiao/itcloudagent/logs/agent.log |grep -e 'ERROR|WAN' | wc -l` -gt 0 ];then
		echo "tail -1000 /opt/yunqiao/itcloudagent/logs/agent.log |grep -e  'ERROR|WAN' --check failed." && return 1
	fi
}
function agent_install()
{
	#安装前检查
	prepare_for_install
	if [ $? -ne 0 ];then
		echo "Pre installation inspection failed." && return 1
	fi
	
	do_install
	if [ $? -ne 0 ];then
		echo "install agent failed." && return 1
	fi
	
	check_after_install
	if [ $? -ne 0 ];then
		echo "install agent failed." && return 1
	fi
}
function main()
{
	telnet_Check
	if [ $? -ne 0 ];then
		echo "telnet_Check failed." && exit 1
	fi
	
	agent_check
	if [ $? -ne 0 ];then
		echo "agent_check failed." && exit 1
	fi
	
	yunqiao_user_add
	if [ $? -ne 0 ];then
		echo "add user yunqiao failed." && exit 1
	fi
	
	agent_install
	if [ $? -ne 0 ];then
		echo "add user yunqiao failed." && exit 1
	fi
	
	echo "install yunqiao agent success."
}
main