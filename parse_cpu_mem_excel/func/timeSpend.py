"""
pandas,openpyxl,xlrd 处理excel，csv， xls文件耗时分析
"""
import os, time
import pandas as pd
from openpyxl import Workbook, load_workbook
import xlrd

workdir = os.getcwd()
excel_file = workdir + "\\input\\cmmerge1-20210913.xlsx"
csv_file = workdir + "\\input\\cmmerge1-20210913.csv"
xls_file = workdir + "\\input\\cmmerge1-20210913.xls"

t0 = time.time()
df = pd.read_excel(excel_file,engine='openpyxl')
t1 = time.time()
print(t1-t0)

t0 = time.time()
pd.read_csv(csv_file,encoding='gb18030')
t1 = time.time()
print(t1-t0)

def read_excel(read_only=True):
    a = time.time()
    wb = load_workbook(excel_file,read_only=read_only)
    b = time.time()
    print(b - a)

read_excel()
read_excel(read_only=False)

t0 = time.time()
data = xlrd.open_workbook(xls_file)
print(data.sheets()[0])
print(time.time() - t0)