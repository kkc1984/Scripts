import ToolFunctions as tf
import getpass
import sys
import os
import re
import time
from colorama import Fore, Back, Style

if len(sys.argv) == 1:
    os.system('cls')
    user_name = input('Please Enter Current UserName: ')
    password = getpass.getpass('Please Enter Current Password: ')
    os.system('cls')
    print('Enter full path of CSV sheet:')
    my_path = input()
    input_path = tf.checkPath(my_path)

    with open(input_path) as f:
        my_file = f.readlines()[1:]

    tf.menuLoop(my_file, user_name, password)

elif re.search('\/\?|\?', sys.argv[1]):
    os.system('cls')
    print('Program format: \n')
    print('iDracTool.py \"c:\\PATH OF CSV\"\n')
    print('=======================================================================================')
    print('CSV Header format: \n')
    print('First line of CSV Needs to be headers specified below, ipaddress, dc, rack, hostname\n\n')
    print('(ipAddress)   (dc)    (rack)  (hostname)')
    print('10.71.70.10,QTSMIAMI,rack-10,ngesx55-idrac')
    print('========================================================================================\n\n')
    print('valid Datacenter values: QTSMIAMI,PLAS,DLAS,ATL,TOR,VAN\n\n')
    print('Press Enter to Continue.')
    input()

elif len(sys.argv) == 2:
    my_path = sys.argv[1]
    input_path = tf.checkPath(my_path)

    with open(input_path) as f:
        my_file = f.readlines()[1:]

    os.system('cls')
    user_name = input('Please Enter Current UserName: ')
    password = getpass.getpass('Please Enter Current Password: ')
    os.system('cls')
    confirm = input('Change Current password (Y/N): ')

    while len(re.findall('[yYnN]', confirm)) == 0 or len(re.findall('[yYnN]', confirm)) > 1:
        os.system('cls')
        print('%s%sERROR: Invalid Selection!!' % (Fore.RED, Back.YELLOW))
        print(Style.RESET_ALL)
        time.sleep(2)
        os.system('cls')
        confirm = input('Change Current password (Y/N): ')

    if len(re.findall('[yY]', confirm)) > 0:
        new_pass = getpass.getpass('Please Enter new Password: ')
        confirm_pass = getpass.getpass('Confirm New Password: ')
        while not confirm_pass == new_pass:
            os.system('cls')
            print('%s%spassword Doesn\'t match!!' % (Fore.RED, Back.YELLOW))
            time.sleep(2)
            print(Style.RESET_ALL)
            os.system('cls')
            new_pass = getpass.getpass('Please Enter new Password: ')
            confirm_pass = getpass.getpass('Confirm New Password: ')

        tf.commandLineRun(my_file, user_name, password, new_pass)
    else:
        tf.commandLineRun(my_file, user_name, password)



