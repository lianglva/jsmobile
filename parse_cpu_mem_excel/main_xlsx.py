"""
服务器性能数据分析
pandas处理excel文件效率太低了，废弃
"""
import os, os.path, time
import numpy as np
import pandas as pd
import openpyxl
from func.commonFunc import calcRowNum, letterToNum

columnName = ["名称", "IP地址IPv4", "CPUAVG", "CPUMAX", "memoryAVG", "memoryAVG"]
workdir = os.getcwd()
inputPathFileList = []
outputFileName = "output.xlsx"
selectColumnLetter = ('F', 'G', 'L', 'M', 'Q', 'R')

# 不可修改全局参数
selectColumnNum = [ letterToNum(i) for i in selectColumnLetter ]
print(selectColumnNum)
outputPathFile = workdir + "\\output\\" + outputFileName
def calc_avg(input_list) -> float:
    i_sum = 0
    for number in input_list:
        i_sum = i_sum + number
    result = i_sum/len(input_list)
    return "%.8f" % result

def main():
    max_line = 0
    #获取所有excel文件列表
    for excel_file in os.listdir(workdir + "\\input"):
        inputPathFile = workdir + "\\input\\" + excel_file
        if inputPathFile.endswith('xlsx'):
            inputPathFileList.append(inputPathFile)
            #获取一次xlsx文件的总行数，默认所有文件行数一样
            if max_line == 0:
                df = pd.read_excel(inputPathFile)
                max_line = len(df.index.values)

    writer = pd.ExcelWriter(outputPathFile)
    for i in range(0,max_line):    #test
        temp_list = []
        cpu_avg_list = []
        cpu_max_list = []
        memory_avg_list = []
        memory_max_list = []
        for excel_file in inputPathFileList:
            df = pd.read_excel(excel_file)
            if len(temp_list) == 0:
                temp_list.append(df.iloc[i, 5])
            if len(temp_list) == 1:
                temp_list.append(df.iloc[i, 6])
            cpu_avg_list.append(df.iloc[i, 11])
            cpu_max_list.append(df.iloc[i, 12])
            memory_avg_list.append(df.iloc[i, 16])
            memory_max_list.append(df.iloc[i, 17])
        #求平均
        cpu_avg = calc_avg(cpu_avg_list)
        cpu_max = calc_avg(cpu_max_list)
        memory_avg = calc_avg(memory_avg_list)
        memory_max = calc_avg(memory_max_list)
        #添加
        temp_list.append(cpu_avg)
        temp_list.append(cpu_max)
        temp_list.append(memory_avg)
        temp_list.append(memory_max)
        #写文件
        temp_list = np.array(temp_list).reshape(1,6)
        df_data = pd.DataFrame(data=temp_list,columns=columnName)
        if i == 0:
            df_data.to_excel(writer,'Sheet1',index=False)
        if i > 0:
            df_data.to_excel(writer, 'Sheet1', header=False, index=False, startrow=i+1)
    writer.save()

if __name__ == "__main__":
    t0 = time.time()
    main()
    t1 = time.time()
    print("运行耗时：%.2f s" % (t1 - t0))