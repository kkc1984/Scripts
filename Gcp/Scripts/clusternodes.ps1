get-service termservice | stop-service -force
$configpath = get-content c:\windows\temp\config.txt
$mydate = (get-date).ToShortDateString()
$myserver = import-csv ($configpath + 'ServerConfig\' + $env:computername + '.csv')
$myerror = $null
$nodelist = get-childitem ($configpath + 'serverconfig') | where{$_.LastWriteTime.tostring() -match $mydate}

$computerinfo = import-csv $nodelist.pspath

$nodes = ($computerinfo | where{$_.clustername -match ($myserver.clustername)}).servername

function logger
{
    param($message)
    
    if($message)
    {
        foreach($i in $message)
        {
            $i.tostring() + ' ' + (get-date).ToShortDateString() + ' ' + (get-date).ToShortTimeString() | out-file ($configpath + 'ServerLogs\' + $env:computername + '.txt') -append 
        }
    }
}


logger "sleeping for 120 waiting for Failover Cluster"
sleep 120

function format-drives
{
    param($driveletter,$label,$drivesize)

    if($driveletter -eq 's')
    {
        $sp = Get-StoragePool | where{$_.friendlyname -match 's2d'}
        $remaining = $sp.size - $sp.AllocatedSize
    }

    if($drivesize -match '[a-zA-Z]' -and $drivesize -notmatch '-')
    {
        $driveletter = $drivesize.substring($drivesize.Length-1)
        $label = 'Data'
        $drivesize = $drivesize.Substring(0,$drivesize.Length-1)
        $round = $drivesize - ($drivesize % 10)
        $newsize = ($round - (($round * 5)/100)) * 1gb
        
           
    }
    elseif($drivesize -match '[a-zA-Z]' -and $drivesize -match '-')
    {
        
        $driveletter = $drivesize.split('-')[0].substring($drivesize.split('-')[0].Length-1)
        $label = $drivesize.split('-')[1]   
        $drivesize = $drivesize.Substring(0,$drivesize.split('-')[0].Length-1)
        $round = $drivesize - ($drivesize % 10)
        $newsize = ($round - (($round * 5)/100)) * 1gb
        

         
    }
    else
    {
        $driveletter = $driveletter
        $label = $label
        $round = $drivesize - ($drivesize % 10)
        $newsize = ($round - (($round * 5)/100)) * 1gb
        
        
    }

    if($remaining)
    {
        $remaining = $remaining/1gb
        $round = ($remaining - ($remaining % 10))/2
        $newsize = ($round - (($round * 3.6)/100)) * 1gb
    }
    
    New-Volume -FriendlyName $label -FileSystem CSVFS_ReFS -Size $newsize -AllocationUnitSize 65536 -ResiliencySettingName Mirror -PhysicalDiskRedundancy 1 -verbose
    Get-ClusterSharedVolume -Name “Cluster Virtual Disk ($($label))” | Remove-ClusterSharedVolume -Verbose
    Get-Partition -Volume (Get-Volume -FileSystemLabel $($label)) | Set-Partition -NewDriveLetter $driveletter -Verbose
}

logger -message 'creating cluster object'

$log = new-cluster -name $($myserver.clustername) -node $nodes[0],$nodes[1] -StaticAddress $($myserver.apip) -ErrorVariable myerror -verbose
logger $log
logger $myerror

##############
switch -regex ($Myserver.env)
{
    'p'
    {
        $clusname = $myserver.clustername
        $key = get-content ($configpath + 'file')
        $dom = get-content ($configpath + 'file2') | Convertto-SecureString -key $Key
        $domainacct = new-object -typename System.Management.Automation.PSCredential -argumentlist 'domain\user',$dom
    
        invoke-command -ComputerName vm1 -scriptblock `
        {
            param($clusname,$domainacct)
  
            $compobj = get-adcomputer -Identity $clusname -server domain -credential $domainacct
            Add-ADGroupMember -Identity cluster_named_objects -Members $compobj -server domain -credential $domainacct
    
        } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -ArgumentList $clusname,$domainacct

        if($myserver.sd -match 'y')
        {
            if($myserver.zone -match 'us-east1')
            {
                invoke-expression 'c:\support tools\Install_Illumio_VEN_v1.ps1'
                do{sleep 60;logger 'Sleeping for 60s, waiting for illumio install'} while(!(get-service venAgentMonitorSvc 2>$Null))
                $fileshare = 'fs1'
            }
            elseif($myserver.zone -match 'us-east4')
            {
                $fileshare = '\\fs2\quorum\'
            }

            
            
            $sharename = ($fileshare + $($myserver.clusterName) + '-quorum')

            sleep 60

            logger -message "Create quorum directory"
            $dir = new-item -path $fileshare -name ($($myserver.clusterName) + '-quorum') -ItemType Directory
            logger $dir

            $Acl = Get-Acl $sharename
            $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$($myserver.clustername)$", "modify","Allow")
            $n1 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$($nodes[0])$", "modify","Allow")
            $n2 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$($nodes[1])$", "modify","Allow")
            $Acl.SetAccessRule($Ar)
            $Acl.SetAccessRule($n1)
            $Acl.SetAccessRule($n2)
            Set-Acl $sharename $Acl
            
            sleep 60

            $sd = Enable-ClusterStorageSpacesDirect -Confirm:$false
            logger $sd

            #### Formatting the disks
            $sd = format-drives -driveletter 't' -label 'Log' -drivesize $($myserver.Tdrive)
            logger $sd
            $sd = format-drives -driveletter 'e' -label 'TempDB' -drivesize $($myserver.edrive)
            logger $sd
            $sd = format-drives -driveletter 's' -label 'SQL' -drivesize $($myserver.sdrive)
            logger $sd

            logger -message 'Create quorum'
            $qu = Set-ClusterQuorum -FileShareWitness $sharename
            logger $qu
        }
    }
    't'
    {
        $clusname = $myserver.clustername
        $key = get-content ($configpath + 'file')
        $dom = get-content ($configpath + 'file2') | Convertto-SecureString -key $Key
        $domainacct = new-object -typename System.Management.Automation.PSCredential -argumentlist 'domain\user',$dom
    
        invoke-command -ComputerName vm1 -scriptblock `
        {
            param($clusname,$domainacct)
  
            $compobj = get-adcomputer -Identity $clusname -server ca.saas -credential $domainacct
            $log = Add-ADGroupMember -Identity cluster_named_objects -Members $compobj -server domain -credential $domainacct
    
        } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -ArgumentList $clusname,$domainacct

        if($myserver.sd -match 'y')
        {

            invoke-expression 'c:\support tools\Install_Illumio_VEN_v1.ps1'
            do{sleep 60;logger 'Sleeping for 60s, waiting for illumio install'} while(!(get-service venAgentMonitorSvc 2>$Null))
            $fileshare = 'fs1'
            $sharename = ($fileshare + $($myserver.clusterName) + '-quorum')

            sleep 60

            logger -message "Create quorum directory"
            $dir = new-item -path $fileshare -name ($($myserver.clusterName) + '-quorum') -ItemType Directory
            logger $dir

           
            $Acl = Get-Acl $sharename
            $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$($myserver.clustername)$", "modify","Allow")
            $n1 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$($nodes[0])$", "modify","Allow")
            $n2 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$($nodes[1])$", "modify","Allow")
            $Acl.SetAccessRule($Ar)
            $Acl.SetAccessRule($n1)
            $Acl.SetAccessRule($n2)
            Set-Acl $sharename $Acl

            sleep 60

            $sd = Enable-ClusterStorageSpacesDirect -Confirm:$false
            logger $sd

            #### Formatting the disks
            $sd = format-drives -driveletter 't' -label 'Log' -drivesize ($myserver.Tdrive)
            logger $sd
            $sd = format-drives -driveletter 'e' -label 'TempDB' -drivesize ($myserver.edrive)
            logger $sd
            $sd = format-drives -driveletter 's' -label 'SQL' -drivesize ($myserver.sdrive)
            logger $sd

            logger -message 'Create quorum'
            $qu = Set-ClusterQuorum -FileShareWitness $sharename
            logger $qu

        }
    }
    'd'
    {
        $clusname = $myserver.clustername
        $key = get-content ($configpath + 'file')
        $dom = get-content ($configpath + 'file2') | Convertto-SecureString -key $Key
        $domainacct = new-object -typename System.Management.Automation.PSCredential -argumentlist 'domain\user',$dom
    
        invoke-command -ComputerName vm1 -scriptblock `
        {
            param($clusname,$domainacct)
  
            $compobj = get-adcomputer -Identity $clusname -server dev.us.corp -credential $domainacct
            Add-ADGroupMember -Identity cluster_named_objects -Members $compobj -server domain -credential $domainacct
    
        } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -ArgumentList $clusname,$domainacct

        if($myserver.sd -match 'y')
        {
            $fileshare = 'fs1'
            $sharename = ($fileshare + $($myserver.clusterName) + '-quorum')

            sleep 60

            logger -message "Create quorum directory"
            $dir = new-item -path $fileshare -name ($($myserver.clusterName) + '-quorum') -ItemType Directory
            logger $dir

            $Acl = Get-Acl $sharename
            $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$($myserver.clustername)$","modify","Allow")
            $n1 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$($nodes[0])$","modify","Allow")
            $n2 = New-Object System.Security.AccessControl.FileSystemAccessRule("domain\$($nodes[1])$","modify","Allow")
            $Acl.SetAccessRule($Ar)
            $Acl.SetAccessRule($n1)
            $Acl.SetAccessRule($n2)
            Set-Acl $sharename $Acl
            
            sleep 60

            $sd = Enable-ClusterStorageSpacesDirect -Confirm:$false
            logger $sd

            #### Formatting the disks
            $sd = format-drives -driveletter 't' -label 'Log' -drivesize $($myserver.Tdrive)
            logger $sd
            $sd = format-drives -driveletter 'e' -label 'TempDB' -drivesize $($myserver.edrive)
            logger $sd
            $sd = format-drives -driveletter 's' -label 'SQL' -drivesize $($myserver.sdrive)
            logger $sd

            logger -message 'Create quorum'
            $qu = Set-ClusterQuorum -FileShareWitness $sharename
            logger $qu

        }
    }
}


#############################

net user temp Temp1234! /add /y
$domain = hostname
$temp = 'Temp1234!'

switch -regex ($myserver.env)
{
    'd'
    {
        #Start-Process -NoNewWindow  'c:\us\autologon64.exe' -ArgumentList "tempacct $($domain) T3mp@ccount1234! /accepteula"
        cmd /c 'c:\us\autologon64.exe' temp $($domain) $($temp) /accepteula
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomainName /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoLogonSID /f
        net user temp /delete
        remove-item c:\us\* -force -recurse

        invoke-command -ComputerName $($nodes[1]) -scriptblock `
        {
            net localgroup administrators  domain/user /delete
        } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $domainacct

        net localgroup administrators  domain/user /delete
    }
    'p'
    {
        #Start-Process -NoNewWindow  'C:\support tools\autologon64.exe' -ArgumentList "tempacct $($domain) T3mp@ccount1234! /accepteula"
        cmd /c 'C:\support tools\autologon64.exe' temp $($domain) $($temp) /accepteula
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomainName /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoLogonSID /f
        net user temp /delete
        remove-item 'c:\support tools\installsgcp.ps1' -force
        remove-item 'c:\support tools\clusternodes.ps1' -force
        remove-item 'c:\support tools\gcppre.ps1' -force
        remove-item 'c:\support tools\autologon64.exe' -force
        remove-item 'c:\support tools\*illumio*' -force

        invoke-command -ComputerName $($nodes[1]) -scriptblock `
        {
            net localgroup administrators domain/user /delete
        } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $domainacct

        net localgroup administrators  domain/user /delete
    }
    't'
    {
        #Start-Process -NoNewWindow  'C:\support tools\autologon64.exe' -ArgumentList "tempacct $($domain) T3mp@ccount1234! /accepteula"
        cmd /c 'C:\support tools\autologon64.exe' temp $($domain) $($temp) /accepteula
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomainName /f
        REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoLogonSID /f
        net user temp /delete
        remove-item 'c:\support tools\installsgcp.ps1' -force
        remove-item 'c:\support tools\clusternodes.ps1' -force
        remove-item 'c:\support tools\gcppre.ps1' -force
        remove-item 'c:\support tools\autologon64.exe' -force
        remove-item 'c:\support tools\*illumio*' -force

        invoke-command -ComputerName $($nodes[1]) -scriptblock `
        {
            net localgroup administrators  domain/user /delete
        } -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) -Credential $domainacct

        net localgroup administrators domain/user /delete
    }
}

logger "`nALL SETUP SCRIPTS COMPLETE!!!..." 
restart-computer -force