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
. ../func/*
function main()
{
	./get_linux_os_version.sh
}
main $@