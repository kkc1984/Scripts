import shutil
import re
from colorama import Fore, Back, Style
import time
import os
import threading
import subprocess
import getpass
import paramiko
import ServerInfo
import sys

max_threads = 20
sema = threading.Semaphore(value=max_threads)
threads = []
user_name = ''
password = ''
enable_val = False
sel = ''
menu_check = False


# Main Menu screen
def mainMenu():
    global enable_val
    if not enable_val:
        option_g = '%s%sg. Set Boot Order DISABLED' % (Back.YELLOW, Fore.BLUE)
        option_h = '%s%sh. Set Raid Configs DISABLED' % (Back.YELLOW, Fore.BLUE)
        option_i = '%s%si. Set Cpu Settngs DISABLED' % (Back.YELLOW, Fore.BLUE)
    else:
        option_g = 'g. Set Boot Order ENABLED'
        option_h = 'h. Set Raid Configs ENABLED'
        option_i = 'i. Set Cpu Settngs ENABLED'

    print('======================'.center(shutil.get_terminal_size().columns))
    print('| iDracTool MainMenu |'.center(shutil.get_terminal_size().columns))
    print('======================\n'.center(shutil.get_terminal_size().columns + 1))

    print('a. Change Password')
    print('b. Set Location and Hostname')
    print('c. Set PXE boot on Start')
    print('d. Set SNMP settings')
    print('e. Set AD settings')
    print('f. Set NTP/Dns settings')
    print(option_g)
    print(option_h)
    print(option_i)
    print(Style.RESET_ALL, end='')
    print('j. Get JobQ')
    print('k. Clear JobQ')
    print('l. Ping Servers')
    print('m. RacReset')
    print('n. PowerCycle')
    print('o. Disable usb pass-thru')
    print('w. Enable/Disable buttons g,h,i\n')
    print('x. Exit\n')
    print('Please Enter Selection (a,b,c,d...): ')


# loop to display main menu
def menuLoop(my_file, *args):
    global switcher
    global user_name
    global password
    global enable_val
    global sel
    global menu_check
    os.system('cls')
    menu_check = True

    if user_name == '':
        user_name = args[0]
        password = args[1]

    mainMenu()
    sel = input()

    if sel == 'x':
        sys.exit()
    if sel == 'w' and enable_val == False:
        enable_val = True
        menuLoop(my_file, *args)
    elif sel == 'w' and enable_val == True:
        enable_val = False
        menuLoop(my_file, *args)

    if not enable_val:
        match_letter = re.compile('[a-fj-ow-xA-F-J-OW-X]')
    else:
        match_letter = re.compile('[a-ow-xA-OW-X]')

    while len(re.findall(match_letter, sel)) == 0 or len(re.findall(match_letter, sel)) > 1:
        os.system('cls')
        print('%s%sERROR: Invalid Selection!!' % (Fore.RED, Back.YELLOW))
        print(Style.RESET_ALL)
        time.sleep(2)
        os.system('cls')
        menuLoop(my_file, *args)
        sel = input()

    if len(re.findall('[g-inN]', sel)) > 0:
        print('%s%sAre you Sure with option %s (Y,N):\n' % (Fore.BLUE, Back.YELLOW, sel))
        print('%s\b' % Style.RESET_ALL)
        confirm = input()

        if len(re.findall('[nN]', confirm)) > 0:
            menuLoop(my_file, *args)

    func = switcher.get(sel)

    if sel == 'a':
        os.system('cls')
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

        print(thread(func, my_file, user_name, password, new_pass))
    else:
        print(thread(func, my_file, user_name, password))


# function to check path of csv file
def checkPath(my_path):
    while not os.path.isfile('%s' % my_path):
        os.system('cls')
        print('%s%sError: Check your path' % (Fore.RED, Back.YELLOW))
        print(Style.RESET_ALL)
        time.sleep(1)
        os.system('cls')
        print('Enter full path of CSV sheet:')
        my_path = input()
    return my_path


# function that manages queue of threads
def queue(myfunction, object, *args):
    sema.acquire()
    myfunction(object, *args)
    time.sleep(1)
    sema.release()


# function that calls other functions and adds them to threads
def thread(myfunction, my_file, *args):
    global sel
    global menu_check
    os.system('cls')
    print('Please wait...')

    for object in my_file:
        writeLog(object)
        if not myfunction == pingServer:
            print('Starting ' + object.split(',')[0])
        th = threading.Thread(target=queue, args=(myfunction, object, *args))
        th.start()
        time.sleep(1)
        threads.append(th)

    for th in threads:
        th.join()
    if menu_check == False or sel == 'i' and myfunction == pingServer or sel == 'g' and myfunction == pingServer \
            or sel == 'h' and myfunction == pingServer:
        pass
    else:
        print('\nPress Enter to Continue')
        input()
        menuLoop(my_file, user_name, password)


# function to connect ssh and return client object
def connectSSH(my_file, user_name, password):
    ip = str(my_file.split(',')[0]).strip()
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(ip, 22, user_name, password)
        key_auth = str(ssh.get_transport())
        if 'awaiting auth' in key_auth:
            (ssh.get_transport()).auth_interactive_dumb(user_name)
        return ssh
    except:
        with open(f'{ip}.txt', 'a') as f:
            f.writelines(ip + '\t COULDN\'T CONNECT\n')


# function to change password
def changePassword(my_file, user_name, password, new_pass, *args):
    mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        stdin, stdout, stderr = mysess.exec_command(
            f'racadm config -g cfgUserAdmin -o cfgUserAdminPassword -i 1 {new_pass}')
        output = stdout.readlines()
        writeLog(my_file, ['\nracadm config -g cfgUserAdmin -o cfgUserAdminPassword -i 1\n\n'])
        writeLog(my_file, output)
        print(output)
    else:
        stdin, stdout, stderr = mysess.exec_command(f'racadm set iDRAC.Users.2.Password {new_pass}')
        output = stdout.readlines()
        writeLog(my_file, ['\nracadm set iDRAC.Users.2.Password\n\n'])
        writeLog(my_file, output)
        print(output)

    mysess.close()


# function to write all output into txt file
def writeLog(my_file, *args):
    server = (my_file.split(',')[0])

    if not os.path.isfile(f'{server}.txt'):
        file = open(f'{server}.txt', 'w')
        file.close()
    elif len(args) > 0:
        output = args[0]
        with open(f'{server}.txt', 'a') as f:
            for line in output:
                f.writelines(f'{server} \t {line}')


# function to delete job queue of the server
def getJobQ(my_file, user_name, password):
    mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        writeLog(my_file, [f'\nSystem is CMC no JobQ to List\n\n'])

    else:
        stdin, stdout, stderr = mysess.exec_command('racadm jobqueue view')
        output = stdout.readlines()
        writeLog(my_file, ['\nracadm jobqueue view\n\n'])
        writeLog(my_file, output)
        print(output)
    mysess.close()


# function to delete all jobs in the jobqueue
def delJobQ(my_file, user_name, password):
    mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        writeLog(my_file, [f'\nSystem is CMC no JobQ to delete\n\n'])

    else:
        stdin, stdout, stderr = mysess.exec_command('racadm jobqueue delete -i JID_CLEARALL_FORCE')
        output = stdout.readlines()
        writeLog(my_file, ['\nracadm jobqueue delete -i JID_CLEARALL_FORCE\n\n'])
        writeLog(my_file, output)
        print(output)

        mysess.close()


# function to set snmp settings
def setSnmp(my_file, user_name, password):
    global menu_check

    values = my_file.split(',')
    dc = str(values[1]).upper().strip()

    community_string = ServerInfo.ServerInfo(dc).community_string
    trap = ServerInfo.ServerInfo(dc).trap

    cmc_commands = [
        "racadm config -g cfgOobSnmp -o cfgOobSnmpAgentEnable 1",
        f"racadm config -g cfgOobSnmp -o cfgOobSnmpAgentCommunity {community_string}",
        "racadm config -g cfgAlerting -o cfgAlertingEnable 1",
        f"racadm config -g cfgTraps -o cfgTrapsCommunityName -i 1 {community_string}",
        f"racadm config -g cfgTraps -o cfgTrapsAlertDestIPAddr -i 1 {trap}",
        "racadm config -g cfgTraps -o cfgTrapsEnable -i 1 1",
        "racadm eventfilters set -c cmc.alert.all -n snmp"
    ]
    server_commands = [
        "racadm config -g cfgOobSnmp -o cfgOobSnmpAgentEnable 1",
        f"racadm config -g cfgOobSnmp -o cfgOobSnmpAgentCommunity {community_string}",
        "racadm config -g cfgIpmiLan -o cfgIpmiLanAlertEnable 1",
        f"racadm config -g cfgIpmiLan -o cfgIpmiPetCommunityName {community_string}",
        f"racadm config -g cfgIpmiPet -o cfgIpmiPetAlertDestIpAddr -i 1 {trap}",
        "racadm config -g cfgIpmiPet -o cfgIpmiPetAlertEnable -i 1 1",
        "racadm eventfilters set -c idrac.alert.all -a none -n snmp"
    ]

    mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        for command in cmc_commands:
            stdin, stdout, stderr = mysess.exec_command(f'{command}')
            output = stdout.readlines()
            writeLog(my_file, [f'\n{command}\n\n'])
            writeLog(my_file, output)
            print(output)
    else:
        for command in server_commands:
            stdin, stdout, stderr = mysess.exec_command(f'{command}')
            output = stdout.readlines()
            writeLog(my_file, [f'\n{command}\n\n'])
            writeLog(my_file, output)
            print(output)

    if menu_check:
        mysess.close()
    else:
        Disable_passthru(my_file, user_name, password, mysess)


def Disable_passthru(my_file, user_name, password, *args):
    global menu_check

    if not menu_check:
        mysess = args[0]
    else:
        mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        writeLog(my_file, [f'\nNo usb passthru option available for Chassis\n\n'])
        mysess.close()
    else:

        stdin, stdout, stderr = mysess.exec_command('racadm set idrac.os-bmc.adminstate 0')
        output = stdout.readlines()
        writeLog(my_file, ['\nracadm set idrac.os-bmc.adminstate 0\n\n'])
        writeLog(my_file, output)
        print(output)

        if menu_check:
            mysess.close()
        else:
            setAD(my_file, user_name, password, mysess)


# function to check if server is rebooting
def waitForRestart(my_file, output, mysess):
    server = (my_file.split(',')[0])
    check = [line for line in output if re.search('Commit JID', line)]
    if check != 0:
        job_id = check[0].strip().split('=')[1]
        stdin, stdout, stderr = mysess.exec_command(f'racadm jobqueue view -i{job_id}')
        output = stdout.readlines()
        match = [line for line in output if re.search('Job completed successfully', line, re.I)]

        while len(match) == 0:
            print(f'{server} Server still rebooting waiting for 2 min')
            writeLog(my_file, ['Server still rebooting waiting for 2 min\n'])
            time.sleep(120)
            stdin, stdout, stderr = mysess.exec_command(f'racadm jobqueue view -i{job_id}')
            output = stdout.readlines()
            match = [line for line in output if re.search('Job completed successfully', line, re.I)]
            failure = [line for line in output if re.search('Job failed', line, re.I)]
            if len(failure) != 0:
                writeLog(my_file, ['Reboot couldn\'t complete\n'])
                print(f'{server} Reboot couldn\'t complete')
                break
            elif len(match) != 0:
                writeLog(my_file, ['REBOOT COMPLETE\n'])
                print(f'{server} REBOOT COMPLETE')
    else:
        pass


# function to set AD settings on server
def setAD(my_file, user_name, password, *args):
    global menu_check
    values = my_file.split(',')
    dc = str(values[1]).upper().strip()

    domain = ServerInfo.ServerInfo(dc).domain
    ad_group = ServerInfo.ServerInfo(dc).ad_group
    cmc_commands = [
        "racadm config -g cfgActiveDirectory -o cfgADEnable 1",
        "racadm config -g cfgActiveDirectory -o cfgADType 2",
        f"racadm config -g cfgActiveDirectory -o cfgADDomainController1 {domain}",
        f"racadm config -g cfgActiveDirectory -o cfgADGlobalCatalog1 {domain}",
        "racadm config -g cfgActiveDirectory -o cfgADCertValidationEnable 0"
    ]
    server_commands = [
        "racadm set idrac.ActiveDirectory.Enable 1",
        f"racadm set idrac.ActiveDirectory.DCLookupDomainName {domain}",
        f"racadm set idrac.ActiveDirectory.DomainController1 {domain}",
        f"racadm set idrac.ActiveDirectory.GlobalCatalog1 {domain}",
        "racadm set idrac.ActiveDirectory.Schema 2"
    ]

    if not menu_check:
        mysess = args[0]
    else:
        mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        for command in cmc_commands:
            stdin, stdout, stderr = mysess.exec_command(f'{command}')
            output = stdout.readlines()
            writeLog(my_file, [f'\n{command}\n\n'])
            writeLog(my_file, output)
            print(output)
        for g in range(1, (len(ad_group))):
            cmc_commands_groups = [
                f"racadm config -g cfgStandardSchema -i {g} -o cfgSSADRoleGroupName \"{ad_group[g]}\"",
                f"racadm config -g cfgStandardSchema -i {g} -o cfgSSADRoleGroupDomain \"{ad_group[g]}\"",
                f"racadm config -g cfgStandardSchema -i {g} -o cfgSSADRoleGroupPrivilege 0x1ff"
            ]
            for command in cmc_commands_groups:
                stdin, stdout, stderr = mysess.exec_command(f'{command}')
                output = stdout.readlines()
                writeLog(my_file, [f'\n{command}\n\n'])
                writeLog(my_file, output)
                print(output)
    else:
        for command in server_commands:
            stdin, stdout, stderr = mysess.exec_command(f'{command}')
            output = stdout.readlines()
            writeLog(my_file, [f'\n{command}\n\n'])
            writeLog(my_file, output)
            print(output)
        for g in range(1, (len(ad_group))):
            cmc_commands_groups = [
                f"racadm set idrac.ADgroup.{g}.Domain {domain}",
                f"racadm set idrac.ADgroup.{g}.Name \"{ad_group[g]}\"",
                f"racadm set idrac.ADgroup.{g}.Privilege 0x1ff"
            ]
            for command in cmc_commands_groups:
                stdin, stdout, stderr = mysess.exec_command(f'{command}')
                output = stdout.readlines()
                writeLog(my_file, [f'\n{command}\n\n'])
                writeLog(my_file, output)
                print(output)

    if menu_check:
        mysess.close()
    else:
        setNTP(my_file, user_name, password, mysess)


# function to set NTP settings
def setNTP(my_file, user_name, password, *args):
    global menu_check

    values = my_file.split(',')
    dc = str(values[1]).upper().strip()

    time_zone = ServerInfo.ServerInfo(dc).timezone
    dns_servers = ServerInfo.ServerInfo(dc).dns_servers
    ntp_servers = ServerInfo.ServerInfo(dc).ntp_servers

    cmc_commands = [
        "racadm config -g cfgremotehosts -o cfgRhostsNtpEnable 1",
        f"racadm setractime -z {time_zone}"
    ]

    server_commands = [
        "racadm set idrac.NTPConfigGroup.NTPEnable 1",
        f"racadm set idrac.time.timezone {time_zone}"

    ]

    if not menu_check:
        mysess = args[0]
    else:
        mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        for command in cmc_commands:
            stdin, stdout, stderr = mysess.exec_command(f'{command}')
            output = stdout.readlines()
            writeLog(my_file, [f'\n{command}\n\n'])
            writeLog(my_file, output)
            print(output)

        for i in range(1, 3):
            cmc_commands2 = [
                f"racadm config -g cfgremotehosts -o cfgRhostsNtpServer{i} {ntp_servers[i]}",
                f"racadm config -g cfgLanNetworking -o cfgDNSServer{i} {dns_servers[i]}"
            ]
            for g in range(len(cmc_commands2)):
                stdin, stdout, stderr = mysess.exec_command(f'{cmc_commands2[g]}')
                output = stdout.readlines()
                writeLog(my_file, [f'\n{cmc_commands2[g]}\n\n'])
                writeLog(my_file, output)
                print(output)

    else:
        for command in server_commands:
            stdin, stdout, stderr = mysess.exec_command(f'{command}')
            output = stdout.readlines()
            writeLog(my_file, [f'\n{command}\n\n'])
            writeLog(my_file, output)
            print(output)

        for i in range(1, 3):
            server_commands2 = [
                f"racadm set idrac.NTPConfigGroup.NTP{i} {ntp_servers[i]}",
                f"racadm config -g cfgLanNetworking -o cfgDNSServer{i} {dns_servers[i]}"
            ]

            for g in range(len(server_commands2)):
                stdin, stdout, stderr = mysess.exec_command(f'{server_commands2[g]}')
                output = stdout.readlines()
                writeLog(my_file, [f'\n{server_commands2[g]}\n\n'])
                writeLog(my_file, output)
                print(output)

    if menu_check:
        mysess.close()
    else:
        Pxe(my_file, user_name, password, mysess)


# function to reset idrac
def racReset(my_file, user_name, password):
    mysess = connectSSH(my_file, user_name, password)
    stdin, stdout, stderr = mysess.exec_command('racadm racreset')
    output = stdout.readlines()
    writeLog(my_file, ['\nracadm racreset\n\n'])
    writeLog(my_file, output)
    print(output)
    mysess.close()


# function to ping all ips on csv file
def pingServer(server, *args):
    ip = server.split(',')[0].strip()
    val = subprocess.check_output('powershell test-connection -server %s -count 1 -quiet' % ip, shell=True)
    if re.search('False', str(val)):
        print(ip + ' Not Pingable Check IP')
        return False
    else:
        print(ip + ' Success')
        return True


# function to set pxe boot
def Pxe(my_file, user_name, password, *args):
    global menu_check

    server_commands = [
        "racadm config -g cfgServerInfo -o cfgServerBootOnce 0",
        "racadm config -g cfgServerInfo -o cfgServerFirstBootDevice PXE"
    ]

    if not menu_check:
        mysess = args[0]
    else:
        mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        writeLog(my_file, [f'\nSystem is CMC no PXE Configs\n\n'])
    else:
        for command in server_commands:
            stdin, stdout, stderr = mysess.exec_command(f'{command}')
            output = stdout.readlines()
            writeLog(my_file, [f'\n{command}\n\n'])
            writeLog(my_file, output)
            print(output)

    if menu_check:
        mysess.close()
    else:
        locationHostname(my_file, user_name, password, mysess)


# function to set bootorder
def bootOrder(my_file, user_name, password, *args):
    global menu_check

    if not menu_check:
        mysess = args[0]
    else:
        mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        writeLog(my_file, [f'\nSystem is CMC no Boot Configs\n\n'])

    else:
        stdin, stdout, stderr = mysess.exec_command('racadm get bios.biosbootsettings.bootseq')
        output = stdout.readlines()
        match = [line for line in output if re.search('BootSeq=', line, re.I)]
        print(f'Current Boot Sequence is {match}')
        writeLog(my_file, [f'Current Boot Sequence is {match}'])
        if len(match) != 0:
            boot_items = match[0].split('=')[1].split(',')
            if re.search('HardDisk', boot_items[0]) and re.search('NIC.Integrated', boot_items[-1]):
                print('Boot Order is set correctly')
                writeLog(my_file, ['Boot Order is set correctly'])
            else:
                new_boot_order = [i for i in range(0, (len(boot_items)))]
                i = 1
                for item in boot_items:
                    if 'HardDisk' not in item and 'NIC' not in item:
                        new_boot_order[i] = item.strip()
                        i += 1
                    elif 'HardDisk' in item:
                        new_boot_order[0] = item.strip()
                    elif 'NIC' in item:
                        new_boot_order[-1] = item.strip()

                server_commands = [
                    'racadm set bios.biosbootsettings.bootseq ' + ','.join(new_boot_order),
                    'racadm jobqueue create BIOS.Setup.1-1 -r pwrcycle -s TIME_NOW'
                ]
                for command in server_commands:
                    stdin, stdout, stderr = mysess.exec_command(f'{command}')
                    output = stdout.readlines()
                    writeLog(my_file, [f'\n{command}\n\n'])
                    writeLog(my_file, output)
                    print(output)

                waitForRestart(my_file, output, mysess)

        else:
            pass

    if menu_check:
        mysess.close()
    else:
        cpuConfig(my_file, user_name, password, mysess)


def pdiskConfig(my_file, mysess):
    server_commands = [
        "racadm storage convertToRaid:Disk.Bay.0:Enclosure.Internal.0-1:RAID.Integrated.1-1",
        "racadm storage convertToRaid:Disk.Bay.1:Enclosure.Internal.0-1:RAID.Integrated.1-1",
        "racadm jobqueue create RAID.Integrated.1-1 -r pwrcycle -s TIME_NOW"
    ]

    stdin, stdout, stderr = mysess.exec_command('racadm raid get pdisks -o -p state')
    output = stdout.readlines()
    match = [line for line in output if re.search('Non-Raid', line, re.I)]
    if len(match) != 0:
        for command in server_commands:
            stdin, stdout, stderr = mysess.exec_command(f'{command}')
            output = stdout.readlines()
            writeLog(my_file, [f'\n{command}\n\n'])
            writeLog(my_file, output)
            print(output)

        waitForRestart(my_file, output, mysess)
    else:
        writeLog(my_file, ['\n\tPdisks are Set\n\n'])


# function to set raid config
def raidConfig(my_file, user_name, password, *args):
    global menu_check

    server_commands = [
        "racadm set bios.BiosBootSettings.HddSeq RAID.Integrated.1-1",
        "racadm storage createvd:RAID.Integrated.1-1 -rl r1 -wp wb -rp ara -ss 64k -pdkey:Disk.Direct.0:RAID.Integrated.1-1,Disk.Direct.1:RAID.Integrated.1-1 -dcp default",
        "racadm jobqueue create RAID.Integrated.1-1 -r pwrcycle -s TIME_NOW"
    ]
    server_commands2 = [
        "racadm raid resetconfig:RAID.Integrated.1-1",
        "racadm raid createvd:RAID.Integrated.1-1 -rl r1 -wp wb -rp ara -ss 64k -pdkey:Disk.Bay.0:Enclosure.Internal.0-1:RAID.Integrated.1-1,Disk.Bay.1:Enclosure.Internal.0-1:RAID.Integrated.1-1 -dcp default",
        "racadm jobqueue create RAID.Integrated.1-1 -r pwrcycle -s TIME_NOW"
    ]

    if not menu_check:
        mysess = args[0]
    else:
        mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        writeLog(my_file, [f'\nSystem is CMC no Raid Configs\n\n'])
    else:
        pdiskConfig(my_file, mysess)
        stdin, stdout, stderr = mysess.exec_command('racadm storage get vdisks')
        output = stdout.readlines()
        match = [line for line in output if re.search('Direct', line, re.I)]
        if len(match) != 0:
            for command in server_commands:
                stdin, stdout, stderr = mysess.exec_command(f'{command}')
                output = stdout.readlines()
                writeLog(my_file, [f'\n{command}\n\n'])
                writeLog(my_file, output)
                print(output)

            waitForRestart(my_file, output, mysess)

        else:
            for command in server_commands2:
                stdin, stdout, stderr = mysess.exec_command(f'{command}')
                output = stdout.readlines()
                writeLog(my_file, [f'\n{command}\n\n'])
                writeLog(my_file, output)
                print(output)

            waitForRestart(my_file, output, mysess)

    if menu_check:
        mysess.close()
    else:
        bootOrder(my_file, user_name, password, mysess)


# function to set cpu config
def cpuConfig(my_file, user_name, password, *args):
    global menu_check
    server_commands = [
        "racadm set BIOS.ProcSettings.ControlledTurbo Disabled",
        "racadm set BIOS.ProcSettings.DcuIpPrefetcher Enabled",
        "racadm set BIOS.ProcSettings.DynamicCoreAllocation Disabled",
        "racadm set BIOS.ProcSettings.LogicalProc Enabled",
        "racadm set BIOS.ProcSettings.ProcAdjCacheLine Enabled",
        "racadm set BIOS.ProcSettings.ProcAts Enabled",
        "racadm set BIOS.ProcSettings.ProcConfigTdp Nominal",
        "racadm set BIOS.ProcSettings.ProcCores All",
        "racadm set BIOS.ProcSettings.ProcExecuteDisable Enabled",
        "racadm set BIOS.ProcSettings.ProcHwPrefetcher Enabled",
        "racadm set BIOS.ProcSettings.QpiSpeed MaxDataRate",
        "racadm set BIOS.ProcSettings.RtidSetting Disabled",
        "racadm set BIOS.ProcSettings.CpuInterconnectBusSpeed MaxDataRate",
        "racadm set BIOS.ProcSettings.ProcSwPrefetcher Enabled",
        "racadm set BIOS.ProcSettings.SubNumaCluster Disabled",
        "racadm set BIOS.ProcSettings.UpiPrefetch Enabled",
        "racadm set BIOS.ProcSettings.ProcX2Apic Disabled",
        "racadm set bios.SysProfileSettings.SysProfile PerfOptimized",
        # "racadm set BIOS.BiosBootSettings.BootMode Bios",
        "racadm jobqueue create BIOS.Setup.1-1 -r pwrcycle -s TIME_NOW"
    ]

    if not menu_check:
        mysess = args[0]
    else:
        mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        writeLog(my_file, [f'\nSystem is CMC no CPU Configs\n\n'])
    else:
        for command in server_commands:
            stdin, stdout, stderr = mysess.exec_command(f'{command}')
            output = stdout.readlines()
            writeLog(my_file, [f'\n{command}\n\n'])
            writeLog(my_file, output)
            print(output)

        waitForRestart(my_file, output, mysess)

    mysess.close()


# function to set hostname and rack location
def locationHostname(my_file, user_name, password, *args):
    global menu_check
    values = my_file.split(',')
    rack_location = str(values[2]).upper().strip()
    host_name = str(values[3]).upper().strip()
    dc = str(values[1]).upper().strip()

    cmc_commands = [
        "racadm setslotname -h 2",
        f"racadm config -g cfgLocation -o cfgLocationDataCenter \'{dc}\'",
        f"racadm config -g cfgLocation -o cfgLocationRack \'{rack_location}\'",
        f"racadm config -g cfgLanNetworking -o cfgDNSRacName \'{host_name}\'",
        f"racadm setsysinfo -c chassisname \'{host_name}\'"
    ]
    server_commands = [
        f"racadm set System.Location.DataCenter \'{dc}\'",
        f"racadm set System.Location.Rack.Name \'{rack_location}\'",
        f"racadm set iDRAC.NIC.DNSRacName \'{host_name}\'"
    ]

    if not menu_check:
        mysess = args[0]
    else:
        mysess = connectSSH(my_file, user_name, password)

    if checkChassis(mysess):
        for command in cmc_commands:
            stdin, stdout, stderr = mysess.exec_command(f'{command}')
            output = stdout.readlines()
            writeLog(my_file, [f'\n{command}\n\n'])
            writeLog(my_file, output)
            print(output)
    else:
        for command in server_commands:
            stdin, stdout, stderr = mysess.exec_command(f'{command}')
            output = stdout.readlines()
            writeLog(my_file, [f'\n{command}\n\n'])
            writeLog(my_file, output)
            print(output)

    if menu_check:
        mysess.close()
    else:
        raidConfig(my_file, user_name, password, mysess)


# command line option that sets up the idrac
def commandLineRun(my_file, user_name, password, *args):
    thread(setSnmp, my_file, user_name, password)
    if len(args) == 1:
        new_pass = args[0]
        thread(changePassword, my_file, user_name, password, new_pass)

    sys.exit()


# function to check if chassis or server
def checkChassis(mysess):
    stdin, stdout, stderr = mysess.exec_command('racadm getsysinfo')
    output = stdout.readlines()
    match = [line for line in output if re.search('fx2', line, re.I)]

    if len(match) != 0:
        return True
    else:
        return False


def PowerCycle(my_file, user_name, password):
    mysess = connectSSH(my_file, user_name, password)
    if checkChassis(mysess):
        writeLog(my_file, [f'\nNo powercycle option available for Chassis\n\n'])
        mysess.close()
    else:

        stdin, stdout, stderr = mysess.exec_command('racadm serveraction powercycle')
        output = stdout.readlines()
        writeLog(my_file, ['\nracadm serveraction powercycle\n\n'])
        writeLog(my_file, output)
        print(output)
        mysess.close()


switcher = {
    'a': changePassword,
    'b': locationHostname,
    'c': Pxe,
    'd': setSnmp,
    'e': setAD,
    'f': setNTP,
    'g': bootOrder,
    'h': raidConfig,
    'i': cpuConfig,
    'j': getJobQ,
    'k': delJobQ,
    'l': pingServer,
    'm': racReset,
    'n': PowerCycle,
    'o': Disable_passthru
}
