

#$cred = get-credential
$mycoll = @()
$path = 'D:\kevinc\GcpQA\'
$Myhash = @{}
$myhash.clear()
$myarray = Get-ChildItem $path | where{$_.name -match '.csv'}

write-host "Select your Excel Sheet:" -f yellow
for($i=1;$i -le $Myarray.count; $i++)
{
                    
    write-host "$i. $($myarray[$i-1].name)" -f green
    $myhash.add($i,$myarray[$i-1])
}

write-host "Enter Selection (1,2,3,4,5):" -f yellow
[int]$answer = read-host

$computerinfo = import-csv $myhash[$answer].pspath

foreach ($item in $computerinfo)
{
    write-host "_____________________" -f yellow
    write-host "∙$($item.servername)∙" -f green
    write-host "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯" -f yellow

    $name = $item.servername.trimend()
    $server = Get-GceInstance -project $item.project | where{$_.name -match "^$($item.servername)$"}
    $describe = gcloud compute instances describe $($server.name) --project=$($item.project) --zone=$($server.zone)
    
    $wsfc = $null
    if(($server.Metadata.items.key | where{$_ -match 'wsfc'}) -ne $null)
    {
        $wsfc = ' true'
    }
    else
    {
        $wsfc = ' false'
    }

    if($server -ne $Null)
    {
        $mysess = New-CimSession -computername $name
        $disks = (Get-ciminstance win32_logicaldisk -CimSession $mysess) | where{$_.drivetype -match '3'}
        $vol = Get-CimInstance win32_volume -CimSession $mysess

        $myobject = New-Object -TypeName psobject -Property @{
            Project = $item.project
            Name = $server.name
            CpuPlatform = $server.CpuPlatform
            MachineType = ($server.MachineType).tostring().split('/')[-1]      
            Zone = ($server.Zone).tostring().split('/')[-1]
            ipAddress = $server.NetworkInterfaces.networkip
            NumDisks = $server.Disks.count
            Jira = $server.labels.values
            Subnet =  ($server.NetworkInterfaces.subnetwork).tostring().split('/')[-1]
            DeletionProtection= ($describe | select-string 'deletion').tostring().trimend().trimstart().split(':')[-1]
            IpForward = ($describe | select-string 'canipforward').tostring().trimend().trimstart().split(':')[-1]
            WSFC = $wsfc
            OS = (Get-ciminstance win32_operatingsystem -CimSession $mysess).caption
            NumCpu = (Get-CimInstance Win32_ComputerSystem -CimSession $mysess).NumberOfLogicalProcessors
            NumMem = ([math]::Round((Get-CimInstance Win32_ComputerSystem -CimSession $mysess).TotalPhysicalMemory/1gb))
            DnsServer = (get-ciminstance Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -CimSession $mysess).dnsserversearchorder |select -first 2

        } | select Project,name,cpuplatform,machinetype,zone,subnet,ipaddress,numdisks,Jira,Deletionprotection,ipforward,wsfc,os,numcpu,nummem,dnsserver


        foreach($Item in $disks)
        {
                
            Add-Member -InputObject $myobject -NotePropertyName ($item.deviceid + ' - Allocation - DriveType') -NotePropertyValue ([math]::Round($item.size/1gb)),($vol | where{$_.caption -match "$($item.deviceid)"}).blocksize
        }
        
        $driveletters = $myobject.psobject.properties | where{$_.name -match ':'}
        
        $i = 0
        foreach($drive in $server.disks.source)
        {
            $mygcedisk = Get-GceDisk -project $myobject.project | where{$_.selflink -match "^$($drive)$"}
            $driveletters[$i].value = "$($driveletters[$i].value) $(($mygcedisk.type).split('/')[-1])"
            $i++
        }

        $golive = $null
        $golive = get-adcomputer $name | where{$_.Distinguishedname -match 'pre-golive'}

        if($golive -ne $Null)
        {
            add-member -InputObject $myobject -NotePropertyName 'InPreGoLive' -NotePropertyValue 'Yes'
        }
        else
        {
            add-member -InputObject $myobject -NotePropertyName 'InPreGoLive' -NotePropertyValue 'No'
        }

        $myobject.jira = $myobject.jira -join ','
        $myobject.dnsserver = $myobject.dnsserver -join ','
        $myobject
        $mycoll += $myobject

        
       
    }
    else
    {
        write-error "$name NOT FOUND"
    }
  
    Remove-CimSession $mysess

}

$coll2 = @()
foreach($obj in $mycoll)
{
    $myobj = $obj
    if(($obj.psobject.Properties | measure-object).count -gt ($myobj.psobject.Properties | measure-object).count)
    {
        $script:myobj = $obj
    }
}

$coll2 += $myobj

($mycoll | where{$_.name -notmatch "$($myobj.name)"}) |% {$coll2 += $_}

$coll2 | Out-GridView

$exp = $null
while($exp -eq $null -or $exp -notmatch 'y|n')
{
    write-host "`n------------------" -f yellow
    write-host "Export to CSV? y/n" -f cyan
    write-host "------------------" -f yellow
    $exp = read-host
    
    if($exp -match 'y')
    {
        $coll2 | export-csv "$($path)$($myhash[$answer].Name.replace('.csv',''))-$((Get-Date -Format d).replace('/','-')).csv" -NoTypeInformation -Verbose
       
    }
}
