import requests
import json
from datetime import date
import ServerInfo as ServerObject
import paramiko

data_center = {
    '1.1.1.1': 'DLAS',
    '1.1.1.2': 'PLAS',
    '1.1.1.3': 'ATL',
    '1.1.1.4': 'QTSMIA',
    '1.1.1.5': 'TOR'
}

response = None


def authenticate_with_ome(ip_address, user_name, password):
    """ X-auth session creation """
    auth_success = False
    session_url = "https://%s/api/SessionService/Sessions" % (ip_address)
    user_details = {'UserName': user_name,
                    'Password': password,
                    'SessionType': 'API'}
    headers = {'content-type': 'application/json'}
    session_info = requests.post(session_url, verify=False,
                                 data=json.dumps(user_details),
                                 headers=headers)
    if session_info.status_code == 201:
        headers['X-Auth-Token'] = session_info.headers['X-Auth-Token']
        auth_success = True
    else:
        error_msg = "Failed create of session with {0} - Status code = {1}"
        print(error_msg.format(ip_address, session_info.status_code))
    return auth_success, headers


def ServerProp(server, ip_address, warranty_info, base_url, headers, duser, dpassword, path):
    global data_center
    global response
    cpu_power = 'NA'
    sysprofile = 'NA'

    my_dc = data_center[ip_address]
    updated = (date.today()).strftime("%m/%d/%Y")
    warranty_end = 'NA'
    start_date = 'NA'

    for warranty in warranty_info:
        if server.get('Identifier') == warranty.get('DeviceIdentifier'):
            warranty_end = (warranty.get('EndDate')).split(' ')[0]
            start_date = (warranty.get('StartDate')).split(' ')[0]
            break

    service_tag = server.get('Identifier')
    model = server.get('Model')
    server_name = server.get('DeviceName')
    chassis_service_tag = server.get('ChassisServiceTag')

    try:
        slot_number = server.get('SlotConfiguration')['SlotNumber']
    except:
        try:
            slot_url = f'{base_url}DeviceService/Devices({server.get("Id")})'
            slot_response = ((requests.get(f'{slot_url}', headers=headers, verify=False)).json()).get(
                'DeviceSpecificData')
            slot_number = str(slot_response['chassisSlot']).replace(' ', '0')
            if len(slot_number) == 1:
                slot_number = f'Slot00{slot_number}'
        except:
            slot_number = 'NA'

    print(server_name)

    firmware_url = f'{base_url}DeviceService/Devices({server.get("Id")})/InventoryDetails'
    firmware_ver = ((requests.get(f'{firmware_url}', headers=headers, verify=False)).json()).get('value')

    ip_address, dns_name = GetVersion(firmware_ver, 'deviceManagement')
    rack_location = '"' + GetVersion(firmware_ver, 'deviceLocation') + '"'

    if 'FX2' in model:
        idrac = GetVersion(firmware_ver, 'deviceSoftware', 'CMC')
    else:

        idrac = GetVersion(firmware_ver, 'deviceSoftware', 'Dell Remote Access')
        try:

            response = requests.get('https://%s/redfish/v1/Systems/System.Embedded.1/Bios' % ip_address, verify=False,
                                    auth=(duser, dpassword))
        except:
            response = None
            cpu_power, sysprofile = connectSSH(ip_address, duser, dpassword)

        if response is not None and response.status_code == 200:
            data = (response.json()).get('Attributes')
            try:
                cpu_power = data['ProcPwrPerf']
            except:
                cpu_power = ''
            try:
                sysprofile = data['SysProfile']
            except:
                sysprofile = ''

    bios = GetVersion(firmware_ver, 'deviceSoftware', 'BIOS')
    nic = GetVersion(firmware_ver, 'deviceSoftware', 'QLogic')
    lifecycle = GetVersion(firmware_ver, 'deviceSoftware', 'Lifecycle Controller')
    perc = GetVersion(firmware_ver, 'deviceSoftware', 'PERC')
    NumCpu, ProcessorType, Cores = GetVersion(firmware_ver, 'serverProcessors')
    NumMem, MemSize = GetVersion(firmware_ver, 'serverMemoryDevices')
    drives = GetVersion(firmware_ver, 'serverArrayDisks')

    my_object = ServerObject.ServerInfo()

    my_object.Versioninfo(server_name, model, ip_address, idrac, lifecycle, nic, service_tag,
                          sysprofile, cpu_power, bios, perc, start_date, warranty_end, updated,
                          my_dc, slot_number, rack_location, chassis_service_tag, dns_name,
                          NumCpu, ProcessorType, NumMem, MemSize, Cores)
## write disk info
    disk_list = []
    if drives != 'NA':
        for disk in drives:
            tag = service_tag
            try:
                disknum = disk['SlotNumber']
            except:
                disknum = 'NA'
            try:
                media = disk['MediaType']
            except:
                media = 'NA'
            try:
                size = disk['Size']
            except:
                size = 'NA'
            try:
                pred = disk['PredictiveFailureState']
            except:
                pred = 'NA'
            disk_list.append(f'{tag},{disknum},{media},{size},{pred}')

    for i in disk_list:
        with open(f'{path}\\{my_dc}Disk.csv', 'a') as f:
            f.writelines(f'{i}\n')

    return my_object


def GetVersion(firmware_ver, inventory_type, *args):
    if args:
        software = args[0]

    for firmware in firmware_ver:
        if firmware.get('InventoryType') == inventory_type:
            version = firmware
            break

    if inventory_type == 'deviceLocation':

        try:
            info = version.get('InventoryInfo')
            rack = (info[0])['Rack']
        except:
            rack = 'NA'

        return rack

    elif inventory_type == 'deviceManagement':

        info = version.get('InventoryInfo')
        ip_address = (info[0])['IpAddress']
        dns_name = (info[0])['DnsName']

        return ip_address, dns_name

    elif inventory_type == 'serverProcessors':
        try:
            info = version.get('InventoryInfo')
            num_cpu = len(info)
            processor = (info[0])['ModelName']
            total_core = 0
            for item in info:
                total_core += int(item['NumberOfCores'])

        except:
            return 'NA', 'NA', 'NA'

        return num_cpu, processor, total_core

    elif inventory_type == 'serverMemoryDevices':
        try:
            info = version.get('InventoryInfo')
            num_mem = len(info)
            total_mem = 0
            for mem in info:
                total_mem += int(mem.get('Size'))
        except:
            return 'NA', 'NA'

        return num_mem, total_mem

    elif inventory_type == 'serverArrayDisks':
        try:
            info = version.get('InventoryInfo')
            if len(info) == 0:
                return 'NA'
            else:
                return info
        except:
            return 'NA'

    else:

        info = version.get('InventoryInfo')
        for ver in info:
            if software in ver.get('DeviceDescription') and ver.get('Status') == 'Installed':
                return ver.get('Version')


def connectSSH(ip_address, duser, dpassword):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        my_sess = ssh.connect(ip_address, 22, duser, dpassword)
        key_auth = str(ssh.get_transport())

        if 'awaiting auth' in key_auth:
            (ssh.get_transport()).auth_interactive_dumb(duser)
        if (ssh.get_transport()).active:

            stdin, stdout, stderr = my_sess.exec_command('racadm get bios.sysprofilesettings')
            output = stdout.readlines()

            for i in output:
                if 'ProcPwrPerf' in i:
                    cpu_power = i.split('=')[1].strip()
                    break
            for i in output:
                if 'SysProfile' in i:
                    sysprofile = i.split('=')[1].strip()
                    break

            my_sess.close()

            return cpu_power, sysprofile
        else:
            cpu_power = 'NA'
            sysprofile = 'NA'
            return cpu_power, sysprofile
    except:
        cpu_power = 'NA'
        sysprofile = 'NA'
        return cpu_power, sysprofile


def writeCsv(server_objects, my_dc, path):
    for i in server_objects:
        myobj = i.result()
        line = f'{myobj.ServerName},{myobj.Model},{myobj.Ip4address},{myobj.Idrac},{myobj.Lifecycle},{myobj.Nic},' \
               f'{myobj.ServiceTag},{myobj.SysProfile},{myobj.CpuPower},{myobj.Bios},{myobj.Perc},{myobj.WarrantyStartDate},{myobj.WarrantyEndDate},' \
               f'{myobj.updated},{myobj.DataCenter},{myobj.SlotNumber},{myobj.RackLocation}' \
               f',{myobj.ChassisServiceTag},{myobj.DnsName},{myobj.NumCpu},{myobj.ProcessorType},{myobj.NumMem},{myobj.MemSize},{myobj.Cores}'

        with open(f'{path}\\{my_dc}.csv', 'a') as f:
            f.writelines(f'{line}\n')
