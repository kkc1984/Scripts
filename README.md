# Scripts

OME ent is module written that hits open manage api to create discovery groups, addserver to custome groups,  and get Dell server info.

gcp folder contains scripts related to google cloud, autodeploy is a script that deploys vms from an excel sheet where you can specify different variables, name, project,
network, num of cpu / memory etc. theres a decom script, and QA scripts. 

driveswap script was used for migrations of current iscsi attached volumes to vmdks. adds 3 new volumes stops sql migrates the data, and removes the current volumes and 
relabels the new volumes with old drive letters 

python folder has some of apps I wrote for data extraction and oob idrac setups, 

idractool sshs into a list of ips provided and sets up various things like adding AD group
access, ntp, snmp, boot order, cpu settings, etc

omeserverinfo hits the OME server API, idrac api thru redfish, and idrac gui scraping data from data not available on the other 2, and collects info from each server. 
i.e. firmware versions, cpu settings, warranty info, servicetags, chassis ips, slot numbers for each blade etc. 
