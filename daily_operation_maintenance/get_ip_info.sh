#!/bin/bash
#********************************************#
# 文件名：get_ip_info.sh     			     #
# 作  者： lvliang                           #
# 日  期：2021年9月17日                      #
# 最后修改：2021年9月17日                    #
# 功  能：获取linux设备ip地址等信息			 #
# 操作系统：RedHat,Suse,Centos				 #
# 复核人：                                   #
#********************************************#
# 捞取序列号
# dmidecode -t 1 |grep 'Serial Number' |cut -d ':' -f 2

# 捞取ip地址
SCRIPYT_PATH=`dirname $0`
. $SCRIPYT_PATH/../func/*

function get_ip_info_redhat7()
{
	arr_interface=(`ifconfig -a | awk '/^[^ ]/&&/:/{print}' | awk -F':' '{print $1}'`)
	arr_ip_address=(`ifconfig -a | awk '/^[^ ]/&&/:/{getline nextline;print nextline}' | sed -r "s/.*inet\s+(\S+)\s+.*/\1/"`)
	arr_netmask=(`ifconfig -a | awk '/^[^ ]/&&/:/{getline nextline;print nextline}' | sed -r "s/.*netmask\s+(\S+)\s*.*/\1/"`)
	
	#
	printf "%-10s %-16s %-15s\n" Interface IpAddress Netmask
	for((i=0;i<${#arr_interface[@]};i++))
	do
		printf "%-10s %-16s %-15s\n" ${arr_interface[i]} ${arr_ip_address[i]} ${arr_netmask[i]}
	done
}
function main()
{
	get_linux_os_type
	# echo $linux_os
	# echo $sub_redhat_os
	case ${linux_os} in
		"redhat")
			case ${sub_redhat_os} in
				"6")
					echo "does not support redhat6 now." && return 1
					;;
				"7")
					get_ip_info_redhat7
					;;
			esac
			;;
		"suse")
			echo "does not support suse now." && return 1
			;;
		"centos")
			echo "does not support centos now." && return 1
			;;
		*)
			echo "does not support ${linux_os} now." && return 1
	esac
}
main $@