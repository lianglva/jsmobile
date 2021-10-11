"""
发送电子邮件
"""
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from func.commonFunc import calc_spent_time
import os.path

@calc_spent_time
def send_email(file):
    output_file = file
    file_name = os.path.basename(output_file)
    #设置服务器所需信息
    #163邮箱服务器地址
    mail_host = 'smtp.qq.com'
    #163用户名
    mail_user = 'lvliang2012@qq.com'
    #密码(部分邮箱为授权码)
    mail_pass = 'rqtrfowjasecbche'
    #邮件发送方邮箱地址
    sender = 'lvliang2012@qq.com'
    #邮件接受方邮箱地址，注意需要[]包裹，这意味着你可以写多个邮件地址群发
    receivers = ['18651954296@163.com']

    #设置email信息
    #邮件内容设置
    message = MIMEMultipart()
    #邮件主题
    message['Subject'] = "IT云主机利用率分析结果"
    #发送方信息
    message['From'] = sender
    #接受方信息
    message['To'] = receivers[0]

    message.attach(MIMEText("EXCEL 汇总表格，请查收","plain",'utf-8'))

    # 构造附件1，传送当前目录下的 test.txt 文件
    att1 = MIMEText(open(output_file, 'rb').read(), 'base64', 'utf-8')
    att1["Content-Type"] = 'application/octet-stream'
    # 这里的filename可以任意写，写什么名字，邮件中显示什么名字
    att1["Content-Disposition"] = 'attachment; filename='+ file_name
    message.attach(att1)

    #登录并发送邮件
    try:
        smtpObj = smtplib.SMTP()
        #连接到服务器
        # smtpObj.connect(mail_host,25)
        smtpObj = smtplib.SMTP_SSL(mail_host)
        #登录到服务器
        smtpObj.login(mail_user,mail_pass)
        #发送
        smtpObj.sendmail(
            sender,receivers,message.as_string())
        #退出
        smtpObj.quit()
        print('success')
    except smtplib.SMTPException as e:
        print('error',e) #打印错误