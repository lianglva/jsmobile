#!/bin/bash
#********************************************#
# 文件名：get_linux_os_version.sh      	     #
# 作  者： lvliang                           #
# 日  期：2021年9月14日                      #
# 最后修改：2021年9月14日                    #
# 功  能：判断linux发型版本		      	     #
# 操作系统：linux							 #
# 复核人：                                   #
#********************************************#
function judge_linux_os_type()
{
	cat /proc/version > /dev/null 2>&1
	if [ $? -eq 0 ];then
		local linux_result=`cat /proc/version | grep -i "redhat" | wc -l`
		if [ ${linux_result} -gt 0 ];then
			linux_os="redhat"
		fi
		local linux_result=`cat /proc/version | grep -iE "\bsuse\b" | wc -l`
		if [ ${linux_result} -gt 0 ];then
			linux_os="suse"
		fi
		local linux_result=`cat /proc/version | grep -i "centos" | wc -l`
		if [ ${linux_result} -gt 0 ];then
			linux_os="centos"
		fi
	fi
	
	case ${linux_os} in
		"redhat")
			local redhat_os=`cat /etc/redhat-release | awk '{print $7}'`
			#redhat 7.6
			echo ${linux_os} ${redhat_os}
			local sub_redhat_os=`echo ${redhat_os} | awk -F'.' '{print $1}'`
			echo ${sub_redhat_os}
			;;
		"suse")
			local suse_os=`lsb_release -r | awk -F' ' '{print $2}'`
			#suse 12.3
			echo ${linux_os} ${suse_os}
			local sub_suse_os=`echo ${suse_os} | awk -F'.' '{print $1}'`
			echo ${sub_suse_os}
			;;
		"centos")
			local centos_os=`cat /etc/redhat-release`
			#CentOS Linux release 7.9.2009 (Core)
			echo ${centos_os}
			local sub_centos_os=`echo ${centos_os} | sed "s/.*release\b\s\+\([0-9.]\+\)/\1/" | awk -F'.' '{print $1}'`
			echo ${sub_centos_os}
			;;
		*)
			echo "Do not support this linux os."
			;;
	esac
}
function main()
{
	judge_linux_os_type
}
main $@