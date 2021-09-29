"""
将多表作为sheet合入一个表格
使用ExcelFile类提升效率
"""

import os, os.path, time
import numpy as np
import pandas as pd
from func.sendEmail import send_email
workdir = os.getcwd()
inputDir = workdir + "\\input"
outputDir = workdir + "\\output"
cmmerge_file = inputDir + "\\merge\\cmmerge_sheet.xlsx"
outputFile = outputDir + "\\output.xlsx"

inputPathFileList = []
columnName = ["名称", "IP地址IPv4", "CPUAVG", "CPUMAX", "memoryAVG", "memoryAVG"]
# [5,6,11,12,16,17]
drop_column = ["资源编号","描述","所属pod","所属科室","架构师责任人","状态","主机类型","所属宿主机IP","CPUSUM",
               "CPU采集次数","CPU采集成功次数","memorySUM","memory采集次数","memory采集成功次数"]
selectColumnLetter = ('F', 'G', 'L', 'M', 'Q', 'R')

# file1 = "D:\\github\\jsmobile\\parse_cpu_mem_excel\\input\\cmmerge1-20210913.xlsx"
# file2 = "D:\\github\\jsmobile\\parse_cpu_mem_excel\\input\\cmmerge1-20210914.xlsx"
def calc_avg(input_list) -> float:
    i_sum = 0
    if len(input_list) == 0:
        return ""
    for number in input_list:
        i_sum = i_sum + number
    result = i_sum/len(input_list)
    return "%.8f" % result

def xlsx_merge():
    writer = pd.ExcelWriter(cmmerge_file)
    sheet = 0
    for f in os.listdir(inputDir):
        daily_xlsx_file = inputDir + "\\" + f
        if daily_xlsx_file.endswith(".xlsx"):
            daily_df = pd.read_excel(daily_xlsx_file)
            #删除多余列
            daily_df.drop(columns=drop_column,axis=1,inplace=True)
            #删除多余行
            daily_df.drop(index=[i for i in range(5,20225)],axis=0,inplace=True)
            daily_df.to_excel(writer, sheet_name=str(sheet), index=False)
            sheet += 1
    writer.save()

def xlsx_analysis():
    merge_df = pd.io.excel.ExcelFile(cmmerge_file)
    data = {}
    max_length = 0
    for sheet_name in merge_df.sheet_names:
        df = pd.read_excel(merge_df,sheet_name)
        if max_length == 0:
            max_length = len(df.index.values)
        data[int(sheet_name)] = df

    writer = pd.ExcelWriter(outputFile)
    for line in range(max_length):
        print("Line: "+ str(line))
        temp_list = []
        cpu_avg_list = []
        cpu_max_list = []
        memory_avg_list = []
        memory_max_list = []
        for sheet in range(len(data)):
            data[sheet].iloc[line,5]
            if len(temp_list) == 0:
                temp_list.append(data[sheet].iloc[line,0])
            if len(temp_list) == 1:
                temp_list.append(data[sheet].iloc[line,1])
            if not pd.isna(data[sheet].iloc[line,2]):
                cpu_avg_list.append(data[sheet].iloc[line,2])
            if not pd.isna(data[sheet].iloc[line,3]):
                cpu_max_list.append(data[sheet].iloc[line,3])
            if not pd.isna(data[sheet].iloc[line, 4]):
                memory_avg_list.append(data[sheet].iloc[line,4])
            if not pd.isna(data[sheet].iloc[line, 5]):
                memory_max_list.append(data[sheet].iloc[line,5])
        # 求平均
        cpu_avg = calc_avg(cpu_avg_list)
        cpu_max = calc_avg(cpu_max_list)
        memory_avg = calc_avg(memory_avg_list)
        memory_max = calc_avg(memory_max_list)
        # 添加
        temp_list.append(cpu_avg)
        temp_list.append(cpu_max)
        temp_list.append(memory_avg)
        temp_list.append(memory_max)

        # 写文件
        temp_list = np.array(temp_list).reshape(1, 6)
        df_data = pd.DataFrame(data=temp_list, columns=columnName)
        if line == 0:
            df_data.to_excel(writer, 'Sheet1', index=False)
        if line > 0:
            df_data.to_excel(writer, 'Sheet1', header=False, index=False, startrow=line + 1)
    writer.save()
def main():
    if not os.path.exists(cmmerge_file):
        xlsx_merge()

    xlsx_analysis()
if __name__ == "__main__":
    t0 = time.time()
    main()
    t1 = time.time()
    print("总运行耗时：%.2f s" % (t1 - t0))
    send_email(outputFile)