get-service termservice | stop-service -force

$configpath = get-content c:\windows\temp\config.txt
$myserver = import-csv ($configpath + 'ServerConfig\' + $env:computername + '.csv')
function logger
{
    param($message)
    $message + ' ' + (get-date).ToShortDateString() + ' ' + (get-date).ToShortTimeString() | out-file ($configpath + 'ServerLogs\' + $env:computername + '.txt') -append 
}



if("$env:computername" -match "hbe" -and $myserver.template -match 'web')
{
    logger 'installing request router package for web/hbe server'
    msiexec /i C:\us\downloads\requestRouter_amd64.msi /passive /norestart /l c:\requestr.txt
    sleep 120
    logger 'installation complete'
}


#(New-Object Net.WebClient).DownloadFile("https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.ps1", "${env:UserProfile}\add-google-cloud-ops-agent-repo.ps1")
#Invoke-Expression "${env:UserProfile}\add-google-cloud-ops-agent-repo.ps1 -AlsoInstall"

net user teamp Temp1234! /add /y
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
