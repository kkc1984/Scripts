
get-service termservice | stop-service -force
$configpath = get-content c:\windows\temp\config.txt

$myserver = import-csv ($configpath + 'ServerConfig\' + $env:computername + '.csv')


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
if($Myserver.clustername -match '[a-zA-Z]' -and $myserver.clustername -notmatch '-')
{
    logger "ip forward selected Installing failover clustering." 
    $fc = Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools
    if($fc.success -match 'true')
    {
        logger "Failover clustering INSTALLED."
        logger "$fc"
        
        if($myserver.index -eq 1)
        {
            
            if($myserver.env -match 'd')
            {
                copy-item ($configpath + 'scripts\Clusternodes.ps1') -Destination c:\us\ -force
                reg add "hklm\software\microsoft\windows\currentversion\runonce" /v install /t reg_sz /d "c:\windows\system32\windowspowershell\v1.0\powershell.exe c:\us\clusternodes.ps1" /f
            }
            else
            {
                copy-item ($configpath + 'scripts\Clusternodes.ps1') -Destination 'c:\support tools' -force
                copy-item ($configpath + 'scripts\illumio-ven-19.3.8-6520.win.x64.msi') -Destination 'c:\support tools' -force
                copy-item ($configpath + 'scripts\Install_Illumio_VEN_v1.ps1') -Destination 'c:\support tools' -force

                New-ItemProperty -Path "hklm:software\microsoft\windows\currentversion\runonce" -Name install -Value "c:\windows\system32\windowspowershell\v1.0\powershell.exe `"& 'c:\support tools\clusternodes.ps1'`"" -PropertyType string -Force
            }
            
            restart-computer -force
            Exit
        }

    }
    else
    {
        logger "Failover clustering INSTALL FAILED."
        logger "$fc"
    }
}

net user teamp Temp1234! /add /y
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
        
        if($myserver.clustername -notmatch '[a-zA-Z]' -or $myserver.clustername -match '-')
        {
            net localgroup administrators domain\user /delete
        }
        
        net user temp /delete
        remove-item c:\us\* -force -recurse
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
        
        if($env:COMPUTERNAME -match 'db|su')
        {
            net localgroup administrators domain\user /add
        }

        if($myserver.clustername -notmatch '[a-zA-Z]' -or $myserver.clustername -match '-')
        {
            net localgroup administrators domain\user /delete
        }
        
        net user temp /delete
        remove-item 'c:\support tools\installsgcp.ps1' -force
        remove-item 'c:\support tools\autologon64.exe' -force
        remove-item 'c:\support tools\gcppre.ps1' -force
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

        if($env:COMPUTERNAME -match 'db|su')
        {
            net localgroup administrators domain\user /add
        }

        if($myserver.clustername -notmatch '[a-zA-Z]' -or $myserver.clustername -match '-')
        {
            net localgroup administrators domain\user /delete
        }

        net localgroup administrators domain\user /delete
        net user temp /delete
        remove-item 'c:\support tools\installsgcp.ps1' -force
        remove-item 'c:\support tools\autologon64.exe' -force
        remove-item 'c:\support tools\gcppre.ps1' -force
    }
}


logger "`nALL SETUP SCRIPTS COMPLETE!!!..." 
restart-computer -force