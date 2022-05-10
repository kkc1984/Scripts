import argparse
from solidfire.factory import ElementFactory


parser = argparse.ArgumentParser()
parser.add_argument("--ip", "-i", required=True, help="Solidfire Cluster IP")
parser.add_argument("--user", "-u", help="Account for loggin in SF", default="ScriptAccount")
parser.add_argument("--password", "-p", required=True, help="Password for Login")
parser.add_argument("--account", "-a", default="1", help="Account that is assinged to solidfire volumes, integer value")
parser.add_argument("--initiator", "-iqn", required=True, help="Initiator of the server")
parser.add_argument("--qos", "-q", default="2", help="qos policy i.e. 1,2,3,4(silver,gold,platinum). Integer value")
parser.add_argument("--Edrive", "-e", required=True, help="Size of Drive E")
parser.add_argument("--Sdrive", "-s", required=True, help="Size of Drive S")
parser.add_argument("--Tdrive", "-t", required=True, help="Size of Drive T")
parser.add_argument("--Servername", "-n", required=True, help="Name of Server")

args = parser.parse_args()
ip_address = args.ip
user_name = args.user
password = args.password
account = args.account
initiator = args.initiator
qos = args.qos
edrive = args.Edrive
sdrive = args.Sdrive
tdrive = args.Tdrive
servername = args.Servername

drive_letters = ['E', 'S', 'T']
drive_sizes = [edrive, sdrive, tdrive]
vol_id = []

sfe = ElementFactory.create(ip_address, user_name, password)

try:
    for i in range(0, 3):
        vol_name = servername.upper() + '-' + drive_letters[i]
        size = int(drive_sizes[i]) * 1073741824

        vol_result = sfe.create_volume(name=vol_name, account_id=int(account), total_size=size, qos_policy_id=int(qos),
                                       associate_with_qos_policy=True, enable512e=False)
        vol_id.append(vol_result.volume_id)

    sfe.create_volume_access_group(name=servername.upper(), volumes=vol_id, initiators=[initiator])
except Exception as e:
    print(e)

