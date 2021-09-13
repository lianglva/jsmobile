#!/bin/bash
#********************************************#
# 文件名：add_static_route.sh      	         #
# 作  者： lvliang                           #
# 日  期：2021年9月10日                      #
# 最后修改：2021年9月13日                    #
# 功  能：自动添加静态路由		      	     #
# 操作系统：linux							 #
# 复核人：                                   #
#********************************************#
#./add_static_route.sh -h 
#./add_static_route.sh -t 
#./add_static_route.sh -p 
#./add_static_route.sh -t -p 
#临时添加路由
#route add -net 10.207.58.0  netmask 255.255.255.0  gw 10.193.113.254 dev bond0
#永久添加路由，重启自动生效 /etc/rc.d/rc.local
arr_route[0]="route add -net 0.0.0.0  netmask 0.0.0.0  gw 192.168.247.2 dev ens33"
arr_route[1]="route add -net 192.168.247.0 netmask 255.255.255.0  gw 0.0.0.0 dev ens33"

ERR_COMMOND_NOT_FOUND=127

function do_user_help()
{
	echo "Usage: bash add_static_route.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t                   add the temporary route."
    echo "  -p                   add the permanent route."
	echo "  --help/-h            display this help and exit"

    return 0
}
function parse_args()
{
	while [ $# -gt 0 ]
	do
		case $1 in
			-h|--help)
				user_help="true"
				shift 1
				;;
			-t)
				temp_route="true"
				shift 1
				;;
			-p)
				perm_route="true"
				shift 1
				;;
			*)
				echo "[Line $LINENO] -bash: $1: This command not found." && exit $ERR_COMMOND_NOT_FOUND
				;;
		esac
	done
}
function do_add_route()
{
	if [ "x${temp_route}" = "xtrue" ];then
		echo "[Line $LINENO] add temporary route"
		echo $@
		`$@`
	fi
	if [ "x${perm_route}" = "xtrue" ];then
		echo "[Line $LINENO] add permanent route"
		echo $@
		echo $@ >> /etc/rc.d/rc.local
	fi
}
function check_route()
{
	
	for((i=0;i<${#arr_route[@]};i++))
	do
		local route_exists=0
		add_net=`echo ${arr_route[i]} | sed -r "s/.*\bnet\s+(([0-9]{1,3}.){3}[0-9]{1,3})\s*.*/\1/"`
		add_mask=`echo ${arr_route[i]} | sed -r "s/.*\bnetmask\s+(([0-9]{1,3}.){3}[0-9]{1,3})\s*.*/\1/"`
		add_gw=`echo ${arr_route[i]} | sed -r "s/.*\bgw\s+(([0-9]{1,3}.){3}[0-9]{1,3})\s*.*/\1/"`
		add_dev=`echo ${arr_route[i]} | sed -r "s/.*\bdev\b\s+(\S+\b).*/\1/"`
		
		add_route=${add_net}":"${add_mask}":"${add_gw}":"${add_dev}
		list_route=`route -n |awk -F' ' '{print $1":"$3":"$2":"$NF}'`
		for route_item in ${list_route}
		do
			if [ ${route_item} = ${add_route} ];then
				echo "[Line $LINENO] this route has alreay exists,no need to add." && route_exists=1 && break
			fi
		done
		if [ ${route_exists} -eq 1 ];then
			continue
		else
			do_add_route ${arr_route[i]}
		fi
	done
}
function main()
{
	local user_help=""
	local temp_route=""
	local perm_route=""
	parse_args $@
	if [[ "x${temp_route}" = "x" && "x${perm_route}" = "x" && "x${user_help}" = "xtrue" ]];then
		do_user_help && exit 0
	fi

	if [[ "x${temp_route}" = "xtrue" || "x${perm_route}" = "xtrue" ]] && [ "x${user_help}" = "xtrue" ];then
		echo "[Line $LINENO] -bash: $1: command not found." && exit $ERR_COMMOND_NOT_FOUND
	fi
	
	#检查路由是否已存在
	check_route
	
}
main $@