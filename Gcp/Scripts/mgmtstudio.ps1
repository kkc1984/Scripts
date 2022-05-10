get-service termservice | stop-service -force

$configpath = get-content c:\windows\temp\config.txt
$myserver = import-csv ($configpath + 'ServerConfig\' + $env:computername + '.csv')

function logger
{
    param($message)
    $message + ' ' + (get-date).ToShortDateString() + ' ' + (get-date).ToShortTimeString() | out-file ($configpath + 'ServerLogs\' + $env:computername + '.txt') -append 
}



$rsCheck = get-service | where{$_.name -eq 'SqlServerReportingServices'} 
$key = get-content "$configpath\admin.key"
$rs = get-content "$configpath\rs.txt" | Convertto-SecureString -key $Key
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($rs)
$p = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

if($myserver.template -eq 'sql' -and $myserver.os -eq '2019' -and $rscheck -eq $Null)
{
    logger 'Installing Reporting Services...'
    start-process -nonewwindow -wait -filepath 'c:\us\downloads\sql2019\Reporting Services Install\SQLServerReportingServices.exe' -argumentlist "/iacceptlicenseterms /passive /norestart /pid=2C9JR-K3RNG-QD4M4-JQ2HR-8468J"
    sleep 30
    $svc = gwmi win32_service -filter "name='SQLServerReportingServices'"
    $svc.stopservice()
    $svc.change($null,$null,$null,$null,$null,$null,'devcorp\svc.eng.sql2',"$($p)",$null,$null,$null)
    $svc.startservice()
    $logs = Get-ChildItem 'c:\windows\temp\ssrs' |?{$_.name -match 'ssrs_[0-9]*\.log'}
    logger (get-content $logs.pspath | select -last 1)

    logger 'Reporting services installed.'

    & 'c:\us\2019 SSRS Configuration Script.ps1'
}



logger 'Installing management studio...'
if($myserver.os -match '2019')
{
    start-process -nonewwindow -wait -filepath 'c:\us\downloads\sql2019\Management studio\SSMS-Setup-ENU.exe' -argumentlist "/install /passive /norestart"
    $logs = Get-ChildItem 'c:\windows\temp\ssmssetup' |?{$_.name -match 'ssms-setup-enu_[0-9]*\.log'}
    logger (get-content $logs.pspath | select -last 1)
}
else
{
    start-process -nonewwindow -wait -filepath 'c:\us\downloads\sql2016\SQL Management Studio 2016\SSMS-Setup-ENU.exe' -argumentlist "/install /passive /norestart"
    $logs = Get-ChildItem 'c:\windows\temp\ssmssetup' |?{$_.name -match 'ssms-setup-enu_[0-9]*\.log'}
    logger (get-content $logs.pspath | select -last 1)
}

logger 'Management Studio installation complete'

sleep 30


#(New-Object Net.WebClient).DownloadFile("https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.ps1", "${env:UserProfile}\add-google-cloud-ops-agent-repo.ps1")
#Invoke-Expression "${env:UserProfile}\add-google-cloud-ops-agent-repo.ps1 -AlsoInstall"

net user temp Temp1234! /add /y
$domain = hostname
$temp = 'Temp1234!'
cmd /c 'c:\us\autologon64.exe' temp $($domain) $($temp) /accepteula
#Start-Process -NoNewWindow  'c:\us\autologon64.exe' -ArgumentList "tempacct $($domain) T3mp@ccount1234! /accepteula"

REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /f
REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /f
REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /f
REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomainName /f
REG delete "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoLogonSID /f
net user tempacct /delete
remove-item c:\us\* -force -recurse

net localgroup administrators domain\user /delete


logger "`nALL SETUP SCRIPTS COMPLETE!!!..." 
restart-computer -force









