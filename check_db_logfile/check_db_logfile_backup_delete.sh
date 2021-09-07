#!/bin/ksh
#********************************************#
# 文件名：check_db_logfile_backup_delete.sh  #
# 作  者： lvliang                           #
# 日  期：2021年8月23日                      #
# 最后修改：2021年8月26日                    #
# 功  能：检查数据库日志文件是否备份和删除	 #
# 操作系统：HP Unix							 #
# 复核人：                                   #
#********************************************#
#1，检查已备份的数据库日志是否被删除
#2，检查是否存在没有备份的数据库日志被删除

CHECK_DAYS=1											#检查前N天的日志，默认为1
BACKUP_LOG_PATH="/usr/openv/scripts"					#备份日志文件目录
DELETE_LOG_PATH="/oraclelog/rman_master"				#删除日志文件目录
#DELETE_LOG_PATH="/home/oracle/rman_master"				#删除日志文件目录 -- 无锡
DELETE_LOG_FILE="delete_archivelog_master.sh.out"		#删除的日志文件名称
function change_month_from_word_to_number
{
	###---------------------------------------------------###
	#1、将单词格式的月份转换为数字格式
	###---------------------------------------------------###
	case ${log_month_word} in
		"Jan")
			log_month_num="01"
			;;
		"Feb")
			log_month_num="02"
			;;
		"Mar")
			log_month_num="03"
			;;
		"Apr")
			log_month_num="04"
			;;
		"May")
			log_month_num="05"
			;;
		"Jun")
			log_month_num="06"
			;;
		"Jul")
			log_month_num="07"
			;;
		"Aug")
			log_month_num="08"
			;;
		"Sep")
			log_month_num="09"
			;;
		"Oct")
			log_month_num="10"
			;;
		"Nov")
			log_month_num="11"
			;;
		"Dec")
			log_month_num="12"
			;;
		*)
			echo "Do not support this month : ${log_month_word} ." && return 1
			;;
	esac
}
function change_month_from_number_to_word
{
	###---------------------------------------------------###
	#1、将数字格式的月份转换为单词格式
	###---------------------------------------------------###
	case ${find_start_month_num} in
		"01")
			find_start_month="Jan"
			;;
		"02")
			find_start_month="Feb"
			;;
		"03")
			find_start_month="Mar"
			;;
		"04")
			find_start_month="Apr"
			;;
		"05")
			find_start_month="May"
			;;
		"06")
			find_start_month="Jun"
			;;
		"07")
			find_start_month="Jul"
			;;
		"08")
			find_start_month="Aug"
			;;
		"09")
			find_start_month="Sep"
			;;
		"10")
			find_start_month="Oct"
			;;
		"11")
			find_start_month="Nov"
			;;
		"12")
			find_start_month="Dec"
			;;
		*)
			echo "Do not support this month : ${find_start_month_num} ." && return 1
			;;
	esac
}


function check_backuped_log_delete
{
	###---------------------------------------------------###
	#1、检查hot*out备份文件中的记录是否被删除
	###---------------------------------------------------###
	echo "> BEGIN:检查已备份的数据库日志是否被删除"
	#local need_deleted_count=`echo ${backup_sequence_list} | awk -F' ' '{print NF}'`
	local need_deleted_count=0
	for count in ${backup_sequence_list}
	do
		let need_deleted_count=${need_deleted_count}+1
	done
	local deleted_count=0
	local not_deleted_count=0
	local not_deleted_list=""
	
	for backup_item in ${backup_sequence_list}
	do
		local is_backuped_deleted=`echo ${deleted_sequence_list} | grep ${backup_item} | wc -l`
		if [ ${is_backuped_deleted} -eq 1 ];then
			let deleted_count=${deleted_count}+1
		else
			let not_deleted_count=${not_deleted_count}+1
			not_deleted_list=${not_deleted_list}${backup_item}" "
		fi
	done
	echo "Total need deleted item count is ${need_deleted_count}"
	echo "Total deleted item count is ${deleted_count}"
	if [ ${not_deleted_count} -gt 0 ];then
		echo "Total not deleted count is ${not_deleted_count}"
		echo "Total not deleted items are as below:"
		for item in ${not_deleted_list}
		do
			echo ${item}
		done
	fi
	echo "> END:检查已备份的数据库日志是否被删除"
	echo ""
	echo ""
}
function check_unbacked_log_delete
{
	###---------------------------------------------------###
	#1、检查是否存在没有备份的数据库日志被删除
	###---------------------------------------------------###
	echo "> BEGIN:检查是否存在没有备份的数据库日志被删除"
	local unbackup_num=0
	local unbackup_item_list=""
	for delete_item in ${deleted_sequence_list}
	do
		local is_unbackuped_deleted=`echo ${backup_sequence_list} | grep ${delete_item} | wc -l`
		if [ ${is_unbackuped_deleted} -eq 0 ];then
			#表示删除的日志没有备份
			let unbackup_num=${unbackup_num}+1
			unbackup_item_list=${unbackup_item_list}${delete_item}" "
		fi
	done
	if [ ${unbackup_num} -ne 0 ];then
		echo "There are total ${unbackup_num} records without backup were deleted,details as below:"
		for item in ${unbackup_item_list}
		do
			echo ${item}
		done
	else
		echo "SUCCESS!"
	fi
	echo "> END:检查是否存在没有备份的数据库日志被删除"
}
function find_backup_file_before_N_days
{
	###---------------------------------------------------###
	#1、过滤备份失败的数据库log日志
	#2、根据CHECK_DAYS全局变量筛选需要查询的数据库log日志
	#3、给get_backup_files变量赋值
	###---------------------------------------------------###
	local get_backup_files=""
	local backup_file_list=`ls -t ${BACKUP_LOG_PATH} | grep "hot_archivelog_backup.sh20.*.out"`
	for file in ${backup_file_list}
	do
		local backup_success=`tail ${BACKUP_LOG_PATH}/${file} | grep "ended successfully" | wc -l`
		if [ ${backup_success} -eq 0 ];then
			echo "${BACKUP_LOG_PATH}/${file} backup failed, please check!"
			continue
		fi
		
		local log_year=`tail ${BACKUP_LOG_PATH}/${file} | grep "ended successfully" | awk -F' ' '{print $9}'`
		local log_month_word=`tail ${BACKUP_LOG_PATH}/${file} | grep "ended successfully" | awk -F' ' '{print $6}'`
		local log_day=`tail ${BACKUP_LOG_PATH}/${file} | grep "ended successfully" | awk -F' ' '{print $7}'`
		#将日期规整为两位数
		if [ `expr length ${log_day}` -eq 1 ];then
			log_day="0${log_day}"
		fi
		change_month_from_word_to_number
		if [ $? -ne 0 ];then
			echo "do change_month_from_word_to_number faild,please check."
			return 1
		fi
		
		local backup_day=${log_year}${log_month_num}${log_day}
		if [ ${backup_day} -ge ${find_start_date} ];then
			get_backup_files=${get_backup_files}${BACKUP_LOG_PATH}/${file}" "
		else
			break
		fi
		
	done
	#规整为thread_1_seq_112233格式的列表数据
	backup_sequence_list=`echo ${get_backup_files} | xargs cat | awk -F' ' /"input archived log"/'{gsub("thread=","",$4);gsub("sequence=","",$5);print "thread_"$4"_seq_"$5}'|sort|uniq`
	
}
function substr_delete_log_file
{
	#从指定日期开始截断delete file日志文件
	if [ `expr substr ${find_start_day} 1 1` -eq 0 ];then
		find_start_day=`expr substr ${find_start_day} 2 1`
	fi
	local start_line_num=`grep -n "begin delete archivelog" ${DELETE_LOG_PATH}/${DELETE_LOG_FILE} | grep "${find_start_year}" | grep "${find_start_month} ${find_start_day}" | awk -F':' '{if(NR == 1)print $1}'`
	if [ "x${start_line_num}" != "x" ];then
		#[linux] deleted_sequence_list=`sed -n $start_line_num',$'p ${DELETE_LOG_PATH}/${DELETE_LOG_FILE} | grep "^deleted archived log" -A 1 | grep "archived log file name" | sed "s/.*\/\(thread_[0-9]_seq_[0-9]\+\)\..*/\1/"`
		
		sed -n $start_line_num',$'p ${DELETE_LOG_PATH}/${DELETE_LOG_FILE} > ${BACKUP_LOG_PATH}/check.tmp
		
		local match=0
		cat ${BACKUP_LOG_PATH}/check.tmp | while read line
		do
			if [[ "${line}" = "deleted archived log" && ${match} -eq 0 ]];then
				match=1
				continue
			fi
			if [ ${match} -eq 1 ];then
				echo ${line} >> ${BACKUP_LOG_PATH}/delete_seq.tmp
				match=0
			fi
		done
		if [ -e ${BACKUP_LOG_PATH}/delete_seq.tmp ];then
			deleted_sequence_list=`cat ${BACKUP_LOG_PATH}/delete_seq.tmp | cut -b 62-80`
		fi
		
		#rm -f ${BACKUP_LOG_PATH}/check.tmp ${BACKUP_LOG_PATH}/delete_seq.tmp
	fi

}

function init_params
{
	
	backup_sequence_list=""
	deleted_sequence_list=""
	echo "请输入开始检查的日期： 例如20210823"
	read find_start_date
	if [ `expr length ${find_start_date}` -ne 8 ];then
		echo "输入错误!!!" && return 1
	fi
	find_start_year=`echo ${find_start_date} | cut -b 1-4`
	find_start_month_num=`echo ${find_start_date} | cut -b 5-6`
	find_start_month=""
	change_month_from_number_to_word
	find_start_day=`echo ${find_start_date} | cut -b 7-8`
	
	#处理备份的log文件
	find_backup_file_before_N_days
	if [ $? -ne 0 ];then
		echo "do find_backup_file_before_N_days faild,please check."
		return 1
	fi
	
	#处理delete的log文件
	substr_delete_log_file
	if [ $? -ne 0 ];then
		echo "do substr_delete_log_file faild,please check."
		return 1
	fi
}
function main
{
	begin_check_time=`date +"%Y-%m-%d %H:%M.%S"`
	echo ">>>>>>>>>>>>>>>>>>>>>>>> start check : $begin_check_time <<<<<<<<<<<<<<<<<<<<<<<<"
	
	init_params
	if [ $? -ne 0 ];then
		echo "do init_params faild,please check."
		return 1
	fi
	
	check_backuped_log_delete
	if [ $? -ne 0 ];then
		echo "do check_backuped_log_delete faild,please check."
		return 1
	fi
	
	check_unbacked_log_delete
	if [ $? -ne 0 ];then
		echo "do check_unbacked_log_delete faild,please check."
		return 1
	fi
	
	end_check_time=`date +"%Y-%m-%d %H:%M.%S"`
	echo ">>>>>>>>>>>>>>>>>>>>>>>> end check : $end_check_time <<<<<<<<<<<<<<<<<<<<<<<<"
}
main
