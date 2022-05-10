
################################################################################
function addprop 
{
    param
    (
        $name,
        $value
    )
    try
    {
        $item | Add-Member -NotePropertyName $name -NotePropertyValue $value -ea Stop
    }
    catch
    {
        $item.$name = $value
    }
}
###############################################################################

function add-toconfigdb
{
    param($serverobj)

    $insertq = 
@"
    insert into expampleconfig (Env,Project,ServerName,Template,NumCpu,NumMem,Ddrive,Edrive,Tdrive,Sdrive,Subnet,Reservation,Clustername,
    Zone,OS,Jira,Ipaddress,apip,lbip,CreationDate,Active,TenantXDrive,IpForward)
 
    values ('$($serverobj.env)','$($serverobj.project)','$($serverobj.servername)','$($serverobj.Template)','$($serverobj.NumCpu)','$($serverobj.NumMem)','$($serverobj.Ddrive)','$($serverobj.Edrive)','$($serverobj.Tdrive)',
    '$($serverobj.Sdrive)','$($serverobj.Subnet)','$($serverobj.Reservation)','$($serverobj.Clustername)','$($serverobj.Zone)','$($serverobj.OS)','$($serverobj.Jira)',
    '$($serverobj.Ipaddress)','$($serverobj.apip)','$($serverobj.lbip)','$($serverobj.CreationDate)','True','$($serverobj.TenantXDrive)','$($serverobj.IpForward)')
"@

    $chk = Invoke-Sqlcmd -Database exampledb -query "select * from expampleconfig where servername = '$($serverobj.servername)'"

    $updateq = 
@"
    update expampleconfig set Env = '$($serverobj.env)',Project = '$($serverobj.Project)',ServerName = '$($serverobj.ServerName)',
    Template = '$($serverobj.Template)',NumCpu = '$($serverobj.NumCpu)',NumMem = '$($serverobj.NumMem)',Ddrive = '$($serverobj.Ddrive)',
    Edrive = '$($serverobj.Edrive)',Tdrive = '$($serverobj.Tdrive)',Sdrive = '$($serverobj.Sdrive)',Subnet = '$($serverobj.Subnet)',
    Reservation = '$($serverobj.Reservation)',Clustername = '$($serverobj.Clustername)',Zone = '$($serverobj.Zone)',OS = '$($serverobj.OS)',
    Jira = '$($serverobj.Jira)',Ipaddress = '$($serverobj.Ipaddress)',apip = '$($serverobj.apip)',lbip = '$($serverobj.lbip)',CreationDate = '$($serverobj.CreationDate)',
    Active = 'True',TenantXDrive = '$($serverobj.TenantXDrive)',IpForward = '$($serverobj.IpForward)'
    Where servername = '$($serverobj.servername)'
"@
    if($chk)
    {
        Invoke-Sqlcmd -Database exampledb -query $updateq
    }
    else
    {
        Invoke-Sqlcmd -Database exampledb -query $insertq
    }
    
}
####################################
function logger
{
    param($message,$servername,$path)
    $message + ' ' + (get-date).ToShortDateString() + ' ' + (get-date).ToShortTimeString() | out-file ($($path) + 'ServerLogs\' + $servername + '.txt') -append 
}
######################################
function add-gcpdisk 
{
    param
    (
        $servername,
        $driveletter,
        $drivesize,
        $project,
        $label,
        $ipaddress,
        $disktype,
        $zone,
        $sd,
        $cred  
    ) 

    if($drivesize -match '[a-zA-Z]' -and $drivesize -notmatch '-')
    {
        $driveletter = $drivesize.substring($drivesize.Length-1)
        $label = 'Data'
        [int]$drivesize = $drivesize.Substring(0,$drivesize.Length-1)
           
    }

    if($drivesize -match '[a-zA-Z]' -and $drivesize -match '-')
    {
        
        $driveletter = $drivesize.split('-')[0].substring($drivesize.split('-')[0].Length-1)
        $label = $drivesize.split('-')[1]   
        [int]$drivesize = $drivesize.Substring(0,$drivesize.split('-')[0].Length-1)
         
    }

    if($sd -eq 'y')
    {
        if($driveletter -eq 'e'){$driveletter = 'vol1'}
        if($driveletter -eq 's'){$driveletter = 'vol2'}
        if($driveletter -eq 't'){$driveletter = 'vol3'}
        if($driveletter -eq 'x'){$driveletter = 'vol4'}
    }

    if($driveletter -match 'x|vol4')
    {
        $disktype = 'pd-standard'
    }
    elseif($driveletter -match 'd')
    {
        $disktype = $disktype
    }
    else
    {
        $disktype = 'pd-ssd'
    }
 
    new-gcedisk -Project $project -DiskName ($servername + "-$driveletter") -zone $zone -sizegb $drivesize -DiskType $disktype     
    
    sleep 3
    $adddisk = $Null
    $adddisk = get-gcedisk -Project $project| ? {$_.name -match ($servername + "-$driveletter")}
    
    if($driveletter -match 'x|vol4')
    {
        $mydisks = New-GceAttachedDiskConfig -Source $adddisk
    }
    else
    {
        $mydisks = New-GceAttachedDiskConfig -Source $adddisk -AutoDelete
    }

    $myinstance = (Get-GceInstance -project $project | ? {$_.name -match "^$servername$"})
    $myinstance | set-gceinstance -AddDisk $mydisks

    if($sd -ne 'y' -or $driveletter -eq 'd')
    {
        Invoke-Command -ComputerName $ipaddress -ScriptBlock `
        { 
            param($driveletter,$label)
    
        
            $disk = (get-disk | ?{$_.partitionstyle -match 'raw'}).number
            "sel disk $($disk)","online disk",'attributes disk clear readonly',"convert gpt","create partition primary","assign letter $($driveletter)","format fs=ntfs label=$($label) quick unit=32k"|diskpart
        
        } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $cred -ArgumentList $driveletter, $label
    }
    else
    {
        Invoke-Command -ComputerName $ipaddress -ScriptBlock `
        { 
    
        
            $disk = (get-disk | ?{$_.partitionstyle -match 'raw'})
            foreach($item in $disk)
            {
                if($Item.operationalstatus -match 'offline')
                {
                    "sel disk $($item.number)","online disk",'attributes disk clear readonly'| diskpart
                }
            }
            
        
        } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $cred
    
    }
}
####################################
function test-psconnection
{
    param
    (
        $ipaddress,
        $cred, 
        $env
    )
    try
    {
        switch -regex ($env)
        {
            'd'
            {
                $tester = invoke-command -ComputerName $ipaddress -scriptblock {hostname} -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $cred 2>$Null
                if($tester -ne $Null)
                {
                    return $true
                }
                else
                {
                    return $false
                }
            }
            'p|t'
            {
                $tester = invoke-command -ComputerName $ipaddress -scriptblock {test-path 'C:\Support Tools\DoneFile.txt'} -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $cred 2>$Null
                if($tester)
                {
                    return $true
                }
                else
                {
                    return $false
                }
            }
        }

        
    }
    catch
    {
        
    }
}
##################################################
function waitforreadystate
{
    param($computerinfo,$cred)
    write-host 'Waiting 1 min for ReadyState...' -f cyan
    sleep 60
    $checker = test-psconnection -ipaddress $computerinfo[-1].ipaddress -cred $cred -env $computerinfo[-1].env
    while ($checker -eq $false)
    {        
        write-host 'Sleeping another 60s' -f cyan
        sleep 60
        $checker = test-psconnection -ipaddress $computerinfo[-1].ipaddress -cred $cred -env $computerinfo[-1].env
    }

    $checklist = @()
    while($checklist.count -ne ($computerinfo | Measure-Object).count)
    {
        foreach($item in $computerinfo)
        {
            $tester = test-psconnection $item.ipaddress -cred $cred -env $item.env
            if($tester -eq $true)
            {
                $checklist += $tester
                write-host "$($checklist.count) out of $(($computerinfo | measure-object).count) available $($item.servername)"
            }
            else
            {
                $checklist = @()
                write-host 'Sleeping for 10s' -f cyan
                sleep 10
                break
                
            }
        }
    }
    write-host 'Ready state starting...sleeping for 60s' -f cyan
    sleep 60
    
}

######################################

function output-jobs
{
    param($computerinfo,$path)
    foreach($Item In $computerinfo)
    {
        Receive-Job -name $item.servername | out-file ($($path) + 'ServerLogs\' + $item.servername + '.txt') -append
    }
    Get-Job | remove-job -Force
}
#############################################convert excel to csv
Function ExcelToCsv  
{
    param($File,$Path)

    $excelFile = convert-path $file
    $Excel = New-Object -ComObject Excel.Application
    $wb = $Excel.Workbooks.Open($excelFile)
	
    foreach ($ws in $wb.Worksheets) 
    {
        $ws.Saveas($path + "computers" + ".csv", 6)
    }

    $Excel.Quit()
}


###################################################################################
$mydate = get-date -Format G
$path = 'D:\kevinc\batch deploy gcp\'
$Myhash = @{}
$myhash.clear()
$myarray = Get-ChildItem $path | where{$_.name -match '.xlsx'}

write-host "Select your Excel Sheet:" -f yellow
for($i=1;$i -le $Myarray.count; $i++)
{
                    
    write-host "$i. $($myarray[$i-1].name)" -f green
    $myhash.add($i,$myarray[$i-1])
}

write-host "Enter Selection (1,2,3,4,5):" -f yellow
[int]$answer = read-host

ExcelToCsv -File $myhash[$answer].pspath -path $path
get-process |?{$_.processname -match 'excel'} | stop-process -force
$computerinfo = $Null
$computerinfo = Import-Csv 'D:\kevinc\batch deploy gcp\computers.csv' -UseCulture
$computerinfo = $computerinfo | where{$_.servername}

switch -regex ($($computerinfo[0].env))
    {
        'd'
        {
            $key = get-content \\fs1\file1
            $adminp = get-content \\fs1\file2| Convertto-SecureString -key $Key
            $localadmin = new-object -typename System.Management.Automation.PSCredential -argumentlist '.\user',$adminp
            $dom = get-content \\fs1\file3 | Convertto-SecureString -key $Key
            $svc = new-object -typename System.Management.Automation.PSCredential -argumentlist 'domain\user',$dom
            $ultipass = get-content \\fs1\file3 | Convertto-SecureString -key $Key
            $gcp =  get-content \\fs1\file4 | Convertto-SecureString -key $Key
            $domainacct = new-object -typename System.Management.Automation.PSCredential -argumentlist 'domain\user',$gcp
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($gcp)
            $p = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
   
        }
        'p'
        {     
            $key = get-content \\fs1\file1
            $adminp = get-content \\fs1\file2| Convertto-SecureString -key $Key
            $localadmin = new-object -typename System.Management.Automation.PSCredential -argumentlist '.\user',$adminp
            $dom = get-content \\fs1\file3 | Convertto-SecureString -key $Key
            $domainacct = new-object -typename System.Management.Automation.PSCredential -argumentlist 'domain\user',$dom
            $ultipass = get-content \\fs1\file4 | Convertto-SecureString -key $Key
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($dom)
            $p = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            
        }
        't'
        {
            $key = get-content \\fs1\file1
            $adminp = get-content \\fs1\file2 | Convertto-SecureString -key $Key
            $localadmin = new-object -typename System.Management.Automation.PSCredential -argumentlist '.\user',$adminp
            $dom = get-content \\fs1\file3 | Convertto-SecureString -key $Key
            $domainacct = new-object -typename System.Management.Automation.PSCredential -argumentlist 'domain\user',$dom
            $ultipass = get-content \\fs1\file4 | Convertto-SecureString -key $Key
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($dom)
            $p = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
              
        }
    }

$computerinfo | export-csv -path ($path + '\archive\computers.csv') -NoTypeInformation -Force
remove-item -path "$($path)computers.csv" -Force

#############check if clusters
$clsunique = $computerinfo.clustername | select -Unique
if(($computerinfo.clustername | measure-object).count -gt 1)
{
    foreach ($item in $clsunique)
    {
        $clobj = $computerinfo |where{$_.clustername -eq $item}
        $clobj[0] | Add-Member -NotePropertyName index -NotePropertyValue 1
        $clobj[1] | Add-Member -NotePropertyName index -NotePropertyValue 2
    }
}

####check bucketperms 
if($computerinfo[0].env -match 'p|t')
{
    $svaccount = ((gcloud iam service-accounts list --project=$($computerinfo[0].project) | select-string 'Compute Engine default').tostring().split(' ') | select-string 'gserviceaccount.com').tostring() | where{$_}
    $chksv = gsutil iam get gs://p-ulti-cs-infrastructure-ff57-provision-startup | select-string "$($svaccount)"

    if($chksv -eq $Null)
    {
        gsutil iam ch serviceAccount:$($svaccount):objectViewer gs://p-ulti-cs-infrastructure-ff57-provision-startup
    }
}


########################################get env
$nodegroups = gcloud compute sole-tenancy node-groups list --project=proj1 | where{$_ -notmatch 'p-g02-b-ng-01'}

foreach($item in $computerinfo)
{

    
    ################get variables from csv
    $servername = $($item.servername).tolower().trimend()
    $item.Servername = $servername

    write-host "_____________________" -f yellow
    write-host "∙$($servername)∙" -f green
    write-host "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯" -f yellow

    $bootdisktype = $($item.bootDisktype)
    $zone = $($item.zone)
    $cpu = $($item.NUMCPU)
    $mem = $($item.NUMMEM)
    $jira = $($item.Jira).tolower()

    if($item.template -notmatch '[A-Za-z]')
    {
        $item.template = 'pre'
    }

    

    if($item.ipforward -eq 'y')
    {
        $ipforward = "--can-ip-forward"
        $meta = "--metadata=enable-wsfc=true"
        $scope = "--scopes=cloud-platform"
    }
    else
    {
        $ipforward = $null
        $meta = $Null
        $scope = $Null
    }
    #################setting mem more than 32
    [int]$mem = $item.nummem
    if($mem -gt 32)
    {
        $ext = "--custom-extensions"
    }
    else
    {
        $ext = $Null
    }

    

    ##################################################
    $project = (Get-GcpProject | ?{$_.name -match "$(($item.project).trimend())" -or $_.projectid -match "$(($item.project).trimend())"}).projectid
    $item.project = $project

    switch -regex ($($item.os))
    {
        '2019'{$ostype = '2019prep'}
        '2019dc'{$ostype = '2019dcprep'}
        '2016'{$ostype = '2016prep'}
        '2012'{$ostype = '2012prep'}
    }

    switch -regex ($($item.env))
    {
        'd'
        {
            $vpc_Project = 'proj1'
            $image_project = 'proj1'
            $tags = '--tags="default-deny,default-allow"'
            $vmtype = "--custom-vm-type=e2"
            
        }
        'p|t'
        {
            $vpc_Project = 'proj1'           
            $image_project = 'proj1'
            $tags = '--tags="default-allow"'
            $vmtype = "--custom-vm-type=n2"

            if($item.ipforward -eq 'y')
            {
                $meta = "--metadata=enable-wsfc=true,windows-startup-script-url=gs://proj1/GCPstartup.ps1"
            }
            else
            {
                $meta = "--metadata=windows-startup-script-url=gs://proj1/GCPstartup.ps1"
            }

            if($item.tenantxdrive -match 'y')
            {
                $nodename = "--node-group=`"$((($nodegroups | where{$_ -match $item.zone}).split(' ') | where{$_})[0])`""
                $nodetemp = $(($nodegroups | where{$_ -match $item.zone}).split(' ') | where{$_})[2]
                $nodeseries = gcloud compute sole-tenancy node-templates list --proj1
                $vmtype = "--custom-vm-type=$(((($nodeseries | where{$_ -match "^$nodetemp"}).split(' ') | where{$_})[2]).split('-')[0])"
                $item.project = 'proj1'
                $project = 'proj1'
            }
            else
            {
                $nodename = $Null
            }
            
        }
        
    }
    ############## setting vm series type
    #if($item.series -ne $Null)
    #{
    #    $vmtype = "--custom-vm-type=$(($item.series).tolower())"
    #    
    #}
    #else
    #{
    #    $vmtype = $null
    #}
    #
    
    
    $image = (get-gceimage -project $($image_project) | where{$_.name -match $ostype}).name
    $subnet = (Get-GceNetwork -Project $($vpc_Project)).subnetworks | ?{$_ -match "$($item.subnet)"}
    $res_sub = ($subnet.replace('https://www.googleapis.com/compute/v1/',''))
    $region = ($subnet | select-string -pattern "$($vpc_project)/.*/subnetworks" | %{ $_.Matches[0].value}).split('/').trimend()[-2]

    if ($Item.reservation -gt 1)
    {        
        $res_ip = $($item.reservation)
        write-host 'Creating Reservation for IP' -f green
        gcloud compute addresses create $servername --subnet=$($res_sub) --addresses=$($res_ip) --region=$($region) --project=$($project)
        $reservation = "--private-network-ip=`"$($res_ip)`""
        write-host 'Reservation Created' -f cyan
    }
    else
    {
        $reservation = $null
    }
    
    #################deploy vm
    write-host "Deploying $servername..." -f cyan
    logger -message 'Deploying Machine...' -servername $servername -path $path
    
    gcloud compute instances create $servername --boot-disk-type=$bootdisktype --project=$project --image=$image --image-project=$image_project `
    --zone=$zone --custom-cpu=$cpu --custom-memory=$mem --subnet=$subnet --no-address --maintenance-policy=MIGRATE --boot-disk-device-name=$servername `
    --deletion-protection --labels=jira="$($jira)" $($vmtype) $($ipforward) $($meta) $($scope) $($reservation) $($tags) $($ext) $($nodename)
    
    #gcloud compute instances update $servername --no-deletion-protection --zone=$zone --project=$project
    
    ###############################getip
    $myinstance = (Get-GceInstance -project $project | ? {$_.name -match "^$servername$"})
    $myip = $myinstance.networkinterfaces.networkip
    addprop -name ipaddress -value $myip
    
    #############################Adding cluster tasks
    if($Item.ipforward -eq 'y' -and $item.clustername -match '[a-zA-Z]' -and $item.clustername -notmatch '-')
    {
        $clustername = ($item.clustername).tolower()
        $apcheck = gcloud compute addresses list --filter="region:( $($region) )" --project=$($project) | select-string "cluster-access-point-$($clustername)"
        $lbcheck = gcloud compute addresses list --filter="region:( $($region) )" --project=$($project) | select-string "load-balancer-ip-$($clustername)"

        if($apcheck -eq $null)
        {
            Write-host "Creating Cluster Accesspoint cluster-access-point-$($clustername)" -f cyan
            gcloud compute addresses create cluster-access-point-$($clustername) --region=$($region) --subnet=$($subnet) --project=$($project)    
            write-host 'Created' -f green
        }
        if($lbcheck -eq $Null)
        {
            write-host "Creating Loadbalancer load-balancer-ip-$($clustername)" -f cyan
            gcloud compute addresses create load-balancer-ip-$($clustername) --region=$($region) --subnet=$($subnet) --project=$($project)    
            write-host 'Created' -f green
        }

        $apcheck = gcloud compute addresses list --filter="region:( $($region) )" --project=$($project) | select-string "cluster-access-point-$($clustername)"
        $apip = ($apcheck.ToString() | select-string -pattern "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" | %{ $_.Matches[0].value})
        addprop -name apip -value $apip
        $lbcheck = gcloud compute addresses list --filter="region:( $($region) )" --project=$($project) | select-string "load-balancer-ip-$($clustername)"
        $lbip = ($lbcheck.ToString() | select-string -pattern "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" | %{ $_.Matches[0].value})
        addprop -name lbip -value $lbip

        $groupchk = gcloud compute instance-groups unmanaged list --filter="name=( $($clustername)-group-$($item.index) )" --project=$($project)
        if($groupchk -eq $null)
        {
            write-host "Creating group $($clustername)-group-$($item.index)" -f cyan
            gcloud compute instance-groups unmanaged create "$($clustername)-group-$($item.index)" --zone=$($zone) --project=$($project)
            write-host 'Created' -f green
        }
        
        gcloud compute instance-groups unmanaged add-instances "$($clustername)-group-$($item.index)" --instances=$($servername) --zone=$($zone) --project=$($project)

    }
    elseif($item.clustername -match '-')
    {
        $clustername = $item.clustername.replace('-','')
        $groupchk = gcloud compute instance-groups unmanaged list --filter="name=( $($clustername)-group-$($item.index) )" --project=$($project)
        $lbcheck = gcloud compute addresses list --filter="region:( $($region) )" --project=$($project) | select-string "load-balancer-ip-$($clustername)"
        
        if($lbcheck -eq $Null)
        {
            write-host "Creating Loadbalancer load-balancer-ip-$($clustername)" -f cyan
            gcloud compute addresses create load-balancer-ip-$($clustername) --region=$($region) --subnet=$($subnet) --project=$($project)    
            write-host 'Created' -f green
        }

        $lbcheck = gcloud compute addresses list --filter="region:( $($region) )" --project=$($project) | select-string "load-balancer-ip-$($clustername)"
        $lbip = ($lbcheck.ToString() | select-string -pattern "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" | %{ $_.Matches[0].value})
        addprop -name lbip -value $lbip
        
        if($groupchk -eq $null)
        {
            write-host "Creating group $($clustername)-group-$($item.index)" -f cyan
            gcloud compute instance-groups unmanaged create "$($clustername)-group-$($item.index)" --zone=$($zone) --project=$($project)
            write-host 'Created' -f green
        }
        
        gcloud compute instance-groups unmanaged add-instances "$($clustername)-group-$($item.index)" --instances=$($servername) --zone=$($zone) --project=$($project)
    }
  
    #################################
    addprop -name CreationDate -value $mydate

    $item | export-csv "$($path)ServerConfig\$($item.servername).csv" -NoTypeInformation

    add-toconfigdb -serverobj $item
    
    logger -message 'Deployments complete' -servername $servername -path $path
    
}
write-host 'Deployments complete' -f green
sleep 30


##################### wait for deployments

waitforreadystate -computerinfo $computerinfo -cred $Localadmin


#################################sysprep systems

#write-host 'Sysprepping Systems...' -f Cyan
#
#
#get-job | Remove-job -Force
#foreach($item in $computerinfo)
#{
#    logger -message 'Sysprepping Systems...' -servername $item.servername
#    $ipadd = $item.ipaddress
#    start-job -Name $item.servername -ScriptBlock `
#    {
#        param($ipadd, $localadmin)
#        Invoke-Command -ComputerName $ipadd -ScriptBlock `
#        { 
#            gcesysprep
#        } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $localadmin
#    } -ArgumentList $ipadd,$localadmin
#}
#
#
#while((get-job | where{$_.state -match 'running'}) -ne $Null)
#{
#    Write-host 'Servers still Sysprepping waiting 60s' -f Cyan
#    sleep 60
#}
#write-host 'Sysprep Complete.' -f green
#sleep 60
#
#output-jobs -computerinfo $computerinfo
#
#write-host 'Starting vms backup..' -f Cyan
#foreach($item in $computerinfo)
#{
#    Start-GceInstance -Project $item.project -name $item.servername -zone $item.zone
#}
#write-host 'Vms Started.' -f green
#
#waitforreadystate -computerinfo $computerinfo -cred $Localadmin

######################################################
write-host 'Setting up Drives..Please wait' -f cyan

foreach($item in $computerinfo)
{
    write-host "$item.servername" -f yellow
    if($($item.ddrive) -gt 1)
    {
        add-gcpdisk -servername $item.servername -driveletter 'd' -project $item.project -ipaddress $item.ipaddress -label 'Data' -drivesize $item.ddrive -disktype $item.DisktypeD -zone $item.zone -cred $localadmin
    }
    if($($item.edrive) -gt 1)
    {
        add-gcpdisk -servername $item.servername -driveletter 'e' -project $item.project -ipaddress $item.ipaddress -label 'TempDB' -drivesize $item.edrive -zone $item.zone -sd $item.sd -cred $localadmin
    }
    if($($item.sdrive) -gt 1)
    {
        add-gcpdisk -servername $item.servername -driveletter 's' -project $item.project -ipaddress $item.ipaddress -label 'SQL' -drivesize $item.sdrive -zone $item.zone -sd $item.sd -cred $localadmin
    }
    if($($item.tdrive) -gt 1)
    {
        add-gcpdisk -servername $item.servername -driveletter 't' -project $item.project -ipaddress $item.ipaddress -label 'Log' -drivesize $item.tdrive -zone $item.zone -sd $item.sd -cred $localadmin
    }

    if($($item.tenantxdrive) -match 'x')
    {
        $xdrivesize = [math]::ceiling([int]$item.sdrive * 1.1 + [int]$item.tdrive * 1.5)
        add-gcpdisk -servername $item.servername -driveletter 'x' -project $item.project -ipaddress $item.ipaddress -label 'Backup' -drivesize $xdrivesize -zone $item.zone -sd $item.sd -cred $localadmin 
    }
}

Write-host 'Drive Setup Complete' -f green

################################# join domain and install scom/tanium
write-host 'Join Domain and initial Setup tasks...' -f cyan

$dnsservers = (get-gceinstance -Project proj1 | %{$_.NetworkInterfaces}).networkip

foreach($item in $computerinfo)
{
    logger -message 'Join Domain and initial Setup tasks...' -servername $item.servername -path $path
    $ipadd = $item.ipaddress

    switch -regex ($($item.env))
    {
        'd'
        {
            if($item.dc -eq 'y')
            {
                $dns = 'ip1,ip2'
            }
            elseif($item.dc -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
            {
                $dns = $item.dc   
            }
            else
            {
                $dns = 'ip1,ip2'
            }
                        
            $rename_admin = 'user'
            $mydomain = 'domain'
            $configpath = '\\path\kevinc\batch deploy gcp\'

            start-job -Name $item.servername -ScriptBlock `
            {
                param($ipadd, $localadmin,$svc,$ultipass,$dns,$rename_admin,$mydomain,$configpath)
                Invoke-Command -ComputerName $ipadd -ScriptBlock `
                { 
                    param($ultipass,$svc,$dns,$rename_admin,$mydomain,$configpath)

                    msiexec.exe /i "C:\windows\SCOM\AMD64\MOMAgent.msi"  /quiet USE_SETTINGS_FROM_AD=0 USE_MANUALLY_SPECIFIED_SETTINGS=1 MANAGEMENT_GROUP=DEV MANAGEMENT_SERVER_DNS=DEV MANAGEMENT_SERVER_AD_NAME=DEV SECURE_PORT=1234 ACTIONS_USE_COMPUTER_ACCOUNT=1 AcceptEndUserLicenseAgreement=1 NOAPM=1
                    & "$env:windir\system32\tzutil.exe" /s "Eastern Standard Time"
                    #Set-DnsClientServerAddress -InterfaceIndex (get-netadapter).ifindex -ServerAddresses $($dns)
                    reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /t REG_DWORD /v EnableLUA /d 0 /f
                    get-localuser 'administrator' |Rename-LocalUser -NewName $rename_admin
                    get-localuser $rename_admin | set-localuser -Password $ultipass
                    get-localuser $rename_admin | set-localuser -PasswordNeverExpires:$true
                    netsh advfirewall set AllProfiles state off
                    $configpath | out-file c:\windows\temp\config.txt
            
                    start-process -NoNewWindow C:\windows\setup\scripts\Tanium.bat
                    Add-Computer -domainname $($mydomain) -Credential $svc
                    sleep 2
                    net localgroup administrators domain\user /add
                   
                    restart-computer -force

                } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $localadmin -ArgumentList $ultipass,$svc,$dns,$rename_admin,$mydomain,$configpath
            } -ArgumentList $ipadd,$localadmin,$svc,$ultipass,$dns,$rename_admin,$mydomain,$configpath
        }
        'p'
        {
            
            $ipsplit = $item.ipaddress.Split('.')
            $iprange = "$($ipsplit[0])\.$($ipsplit[1])\.$($ipsplit[2])\."

            if($item.dc -eq 'y')
            {
                $dns = 'ip1,ip2'
            }
            elseif($item.dc -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
            {
                $dns = $item.dc   
            }
            else
            {
                #$dns = "$($($dnsservers | where{$_ -match $iprange})[0]),$($($dnsservers | where{$_ -match $iprange})[1])"
                if($dns -notmatch '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
                {
                    $dns = 'ip1,ip2'
                }
            }

            $rename_admin = 'user'
            $mydomain = 'domain'
            $configpath = '\\path\kevinc\batch deploy gcp\'

            start-job -Name $item.servername -ScriptBlock `
            {
                param($ipadd, $localadmin,$domainacct,$ultipass,$dns,$rename_admin,$mydomain,$configpath)
                Invoke-Command -ComputerName $ipadd -ScriptBlock `
                { 
                    param($ultipass,$domainacct,$dns,$rename_admin,$mydomain,$configpath)
                    
                    #Set-DnsClientServerAddress -InterfaceIndex (get-netadapter).ifindex -ServerAddresses $($dns)
                    reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /t REG_DWORD /v EnableLUA /d 0 /f
                    get-localuser 'administrator' |Rename-LocalUser -NewName $rename_admin
                    get-localuser $rename_admin | set-localuser -Password $ultipass
                    get-localuser $rename_admin | set-localuser -PasswordNeverExpires:$true
                    $configpath | out-file c:\windows\temp\config.txt
                    

                    
                    Add-Computer -domainname $($mydomain) -Credential $domainacct
                    sleep 2
                    net localgroup administrators domain\user /add
                    net localgroup administrators user /delete
                    restart-computer -force

                } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $localadmin -ArgumentList $ultipass,$domainacct,$dns,$rename_admin,$mydomain,$configpath
            } -ArgumentList $ipadd,$localadmin,$domainacct,$ultipass,$dns,$rename_admin,$mydomain,$configpath
        }
        't'
        {
            
            $ipsplit = $item.ipaddress.Split('.')
            $iprange = "$($ipsplit[0])\.$($ipsplit[1])\.$($ipsplit[2])\."

            if($item.dc -eq 'y')
            {
                $dns = 'ip1,ip2'
            }
            elseif($item.dc -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
            {
                $dns = $item.dc   
            }
            else
            {
                $dns = "$($($dnsservers | where{$_ -match $iprange})[0]),$($($dnsservers | where{$_ -match $iprange})[1])"
                if($dns -notmatch '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
                {
                    $dns = 'ip1,ip2'
                }
            }

            $rename_admin = 'user'
            $mydomain = 'domain'
            $configpath = '\\path\kevinc\batch deploy gcp\'

            start-job -Name $item.servername -ScriptBlock `
            {
                param($ipadd, $localadmin,$domainacct,$ultipass,$dns,$rename_admin,$mydomain,$configpath)
                Invoke-Command -ComputerName $ipadd -ScriptBlock `
                { 
                    param($ultipass,$domainacct,$dns,$rename_admin,$mydomain,$configpath)
                    
                    #Set-DnsClientServerAddress -InterfaceIndex (get-netadapter).ifindex -ServerAddresses $($dns)
                    reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /t REG_DWORD /v EnableLUA /d 0 /f
                    get-localuser 'administrator' |Rename-LocalUser -NewName $rename_admin
                    get-localuser $rename_admin | set-localuser -Password $ultipass
                    get-localuser $rename_admin | set-localuser -PasswordNeverExpires:$true
                    $configpath | out-file c:\windows\temp\config.txt
                    
                    Add-Computer -domainname $($mydomain) -Credential $domainacct
                    sleep 2
                    net localgroup administrators domain\user /add
                    net localgroup administrators user /delete
                    restart-computer -force

                } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $localadmin -ArgumentList $ultipass,$domainacct,$dns,$rename_admin,$mydomain,$configpath
            } -ArgumentList $ipadd,$localadmin,$domainacct,$ultipass,$dns,$rename_admin,$mydomain,$configpath
              
        }
    }


}

while((get-job | where{$_.state -match 'running'}) -ne $Null)
{
    Write-host 'Domain Join Tasks waiting 60s' -f Cyan
    sleep 60
    write-host 'If you see: Closing the remote server shell instance failed ERROR --This is normal' -f yellow
}

output-jobs -computerinfo $computerinfo -path $path

#################################### MUST CHANGE IN SAAS TO domainacct

waitforreadystate -computerinfo $computerinfo -cred $domainacct

############################### add svc account and load scripts for installs
write-host 'Adding domain Account pushing install scripts' -f cyan

foreach($item in $computerinfo)
{
    logger -message 'Adding domain Account pushing install scripts...' -servername $item.servername -path $path
    $ipadd = $item.ipaddress
    
    switch -regex ($item.env)
    {
        'd'
        {
            start-job -Name $item.servername -ScriptBlock `
            {
                param($ipadd, $domainacct,$p)
                Invoke-Command -ComputerName $ipadd -ScriptBlock `
                { 
                    param($p)

                    ipconfig /registerdns
                    cmd /c 'c:\us\autologon64.exe' user domain $p /accepteula
                    reg add "hklm\software\microsoft\windows\currentversion\runonce" /v install /t reg_sz /d "c:\windows\system32\windowspowershell\v1.0\powershell.exe c:\us\installsGCP.ps1"
                    restart-computer -force

                } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $domainacct -ArgumentList $p
            } -ArgumentList $ipadd,$domainacct,$p
        }
        'p'
        {
            start-job -Name $item.servername -ScriptBlock `
            {
                param($ipadd, $domainacct,$p)
                Invoke-Command -ComputerName $ipadd -ScriptBlock `
                { 
                    param($p)

                    ipconfig /registerdns
                    cmd /c 'C:\Support Tools\Autologon64.exe' user domain $p /accepteula
                    New-ItemProperty -Path "hklm:software\microsoft\windows\currentversion\runonce" -Name install -Value "c:\windows\system32\windowspowershell\v1.0\powershell.exe `"& 'c:\support tools\installsGCP.ps1'`"" -PropertyType string -Force
                    restart-computer -force

                } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $domainacct -ArgumentList $p
            } -ArgumentList $ipadd,$domainacct,$p
        }
        't'
        {
            start-job -Name $item.servername -ScriptBlock `
            {
                param($ipadd, $domainacct,$p)
                Invoke-Command -ComputerName $ipadd -ScriptBlock `
                { 
                    param($p)

                    ipconfig /registerdns
                    cmd /c 'C:\Support Tools\Autologon64.exe' user domain $p /accepteula
                    New-ItemProperty -Path "hklm:software\microsoft\windows\currentversion\runonce" -Name install -Value "c:\windows\system32\windowspowershell\v1.0\powershell.exe `"& 'c:\support tools\installsGCP.ps1'`"" -PropertyType string -Force
                    restart-computer -force

                } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $domainacct -ArgumentList $p
            } -ArgumentList $ipadd,$domainacct,$p
        }
        
    }
    


}

while((get-job | where{$_.state -match 'running'}) -ne $Null)
{
    Write-host 'install scripts tasks waiting 60s' -f Cyan
    sleep 60
}

output-jobs -computerinfo $computerinfo -path $path

write-host "`n======COMPLETE=====`n" -F green
write-host 'Done pushing scripts Check progress from Logs folder:' -f Green
write-host '-------------------------------------------------------------' -f yellow 
write-host "$($path)Serverlogs\" -f yellow
write-host '-------------------------------------------------------------' -f yellow 
