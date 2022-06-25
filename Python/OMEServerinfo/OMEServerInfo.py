import ServerInfoFunctions as sf
import requests
import urllib3
import argparse
from argparse import RawTextHelpFormatter
import concurrent.futures
import sys

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
parser = argparse.ArgumentParser(description=__doc__, formatter_class=RawTextHelpFormatter)
parser.add_argument("--ip", "-i", required=True, help="MSM IP")
parser.add_argument("--user", "-u", required=True, help="Username for MSM", default="admin")
parser.add_argument("--password", "-p", required=True, help="Password for MSM")
parser.add_argument("--duser", "-du", default="root")
parser.add_argument("--dpassword", "-dp", required=True)
parser.add_argument("--path", "-pa", required=True)

args = parser.parse_args()
ip_address = args.ip
user_name = args.user
password = args.password
duser = args.duser
dpassword = args.dpassword
path = args.path

my_dc = sf.data_center[ip_address]
file = open(f'{path}\\{my_dc}.csv', 'w')
file.writelines(
    'Servername,Model,Ip4address,Idrac,Lifecycle,Nic,ServiceTag,SysProfile,CpuPower,Bios,Perc,WarrantyStartDate,'
    'WarrantyEndDate,Updated,DataCenter,SlotNumber,RackLocation,ChassisServiceTag,DnsName,NumCpu,'
    'ProcessorType,NumMem,MemSize,Cores,ChassisIP\n')
file.close()

file = open(f'{path}\\{my_dc}Disk.csv', 'w')
file.writelines(
    'ServiceTag,DiskNumber,MediaType,Size,PredictiveFailure\n')
file.close()

auth_success, headers = sf.authenticate_with_ome(ip_address, user_name, password)
base_url = f'https://{ip_address}/api/'

if auth_success:

    all_devices_url = f"{base_url}DeviceService/Devices?$top=5000"
    warranty_url = f"{base_url}WarrantyService/Warranties?$top=5000"
    devices = ((requests.get(all_devices_url, headers=headers, verify=False)).json()).get('value')
    warranty_info = ((requests.get(warranty_url, headers=headers, verify=False)).json()).get('value')
    #my_item = sf.ServerProp(devices[22], ip_address, warranty_info, base_url, headers, duser, dpassword, path)

    with concurrent.futures.ThreadPoolExecutor() as executor:
        server_objects = [executor.submit(sf.ServerProp, dev, ip_address, warranty_info, base_url, headers,
                                          duser, dpassword, path) for dev in devices]

    sf.writeCsv(server_objects, my_dc, path)


    sys.exit()

else:
    raise Exception("Could Not Connect to OME!")
