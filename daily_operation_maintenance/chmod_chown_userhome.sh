#!/bin/bash
#******************************************* #
# 文件名：chmod_chown_userhome.sh      	     #
# 作  者： lvliang                           #
# 日  期：2021年9月8日                       #
# 最后修改：2021年9月8日                     #
# 功  能：应用用户家目录权限修改			 #
# 操作系统：linux							 #
# 复核人：                                   #
#********************************************#
SCRIPTS_PATH=`dirname $0`
#用户名
USER_NAME="lvliang"

#家目录权限，比如755，如果不填则不修改
AUTHORRITY=""

#家目录属组和属主，比如root:root ,如果不填则不修改
GROUP_USER=""

#设置邮件
#邮件标题
MAIL_TITLE="变更用户$USER_NAME通知"
#邮件正文
MAIL_TEXT="修改用户$USER_NAME家目录成功。\n修改用户$USER_NAME权限成功。"
#邮件附件
MAIL_ATTACH_FILE=$SCRIPTS_PATH/create.sh

function check_user()
{
	id ${USER_NAME} > /dev/null 2>&1
	if [ $? -ne 0 ];then
		echo "user ${USER_NAME} does not exists." && return 1
	fi
}
function check_userhome()
{
	local userhome="/home/${USER_NAME}"
	if [ ! -d /home/${USER_NAME} ];then
		echo "userhome /home/${USER_NAME} does not exists." && return 1
	fi
}
function do_chown()
{
	if [ "x${GROUP_USER}" = "x" ];then
		return 0
	fi
	chown -R ${GROUP_USER} /home/${USER_NAME}
	if [ $? -ne 0 ];then
		echo "chown -R ${GROUP_USER} /home/${USER_NAME} failed." && return 1
	fi
}
function do_chmod()
{
	if [ "x${AUTHORRITY}" = "x" ];then
		return 0
	fi
	chmod ${AUTHORRITY} /home/${USER_NAME}
	if [ $? -ne 0 ];then
		echo "chmod ${AUTHORRITY} /home/${USER_NAME} failed." && return 1
	fi
}
function main()
{
	#检查用户是否存在
	check_user
	if [ $? -ne 0 ];then
		echo "check_user failed." && return 1
	fi
	#检查家目录是否存在
	check_userhome
	if [ $? -ne 0 ];then
		echo "check_userhome failed." && return 1
	fi
	#修改属组和属主
	do_chown
	if [ $? -ne 0 ];then
		echo "do_chown failed." && return 1
	fi
	#修改家目录权限
	do_chmod
	if [ $? -ne 0 ];then
		echo "do_chmod failed." && return 1
	fi
}
main $@

#发送邮件
if [ $? -eq 0 ];then
	echo -e $MAIL_TEXT | mail -s $MAIL_TITLE -a $MAIL_ATTACH_FILE ys.lvliang@h3c.com
fi
