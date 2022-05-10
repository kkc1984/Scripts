get-service termservice | stop-service -force

$configpath = get-content c:\windows\temp\config.txt
$myserver = import-csv ($configpath + 'ServerConfig\' + $env:computername + '.csv')

function logger
{
    param($message)
    $message + ' ' + (get-date).ToShortDateString() + ' ' + (get-date).ToShortTimeString() | out-file ($configpath + 'ServerLogs\' + $env:computername + '.txt') -append 
}


mkdir c:\us\downloads

logger 'Copy Sql Files for install'
if($myserver.os -match '2019')
{
    copy-item ($configpath + 'downloads\sql2019') -Destination c:\us\downloads -force -Recurse
    $sqlkey = 'vlkey'
}
else
{
    copy-item ($configpath + 'downloads\sql2016') -Destination c:\us\downloads -force -Recurse
    if($env:computername -match 'UP')
    {
        $sqlkey = 'vlkey'
    }
    else
    {
        $sqlkey = 'vlkey'
    }
}

logger 'copy complete.'
net localgroup Administrators domain\user /add
net localgroup Administrators domain\user2 /add


##########################################################
logger 'Start sql tools Install...'
if($myserver.os -match '2019')
{
    start-process -nonewwindow -wait -filepath $env:systemdrive\us\downloads\sql2019\enterprise\setup.exe -argumentlist "/ACTION=Install /PID=$sqlkey /FEATURES=Tools /QUIETSIMPLE /IACCEPTSQLSERVERLICENSETERMS"
    sleep 20
    $sqlresult = get-content 'C:\Program Files\Microsoft SQL Server\150\Setup Bootstrap\Log\Summary.txt'
    $sqlresult | select -first 10 | out-file ($configpath + 'ServerLogs\' + $env:computername + '.txt') -append 
}
else
{
    start-process -nonewwindow -wait -filepath $env:systemdrive\us\downloads\SQL2016\SQL2016SP2ENT_CU4\setup.exe -argumentlist "/ACTION=Install /PID=$sqlkey /FEATURES=Tools /QUIETSIMPLE /IACCEPTSQLSERVERLICENSETERMS"
    sleep 20
    $sqlresult = get-content 'C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\Log\Summary.txt'
    $sqlresult | select -first 10 | out-file ($configpath + 'ServerLogs\' + $env:computername + '.txt') -append 
}

logger 'Install sql tools complete.'
logger 'Install RDS server.'

install-windowsfeature rds-rd-server


reg add "HKLM\SOFTWARE\Microsoft\MSDTC" /v "AllowOnlySecureRpcCalls" /t "REG_DWORD"  /d 0 /f 
reg add "HKLM\SOFTWARE\Microsoft\MSDTC" /v "FallbackToUnsecureRPCIfNecessary" /t "REG_DWORD"  /d 0 /f 
reg add "HKLM\SOFTWARE\Microsoft\MSDTC" /v "TurnOffRpcSecurity" /t "REG_DWORD"  /d 1 /f 
reg add "HKLM\SOFTWARE\Microsoft\MSDTC\Security" /v "NetworkDtcAccess" /t "REG_DWORD"  /d 1 /f 
reg add "HKLM\SOFTWARE\Microsoft\MSDTC\Security" /v "NetworkDtcAccessAdmin" /t "REG_DWORD"  /d 1 /f 
reg add "HKLM\SOFTWARE\Microsoft\MSDTC\Security" /v "NetworkDtcAccessClients" /t "REG_DWORD"  /d 1 /f 
reg add "HKLM\SOFTWARE\Microsoft\MSDTC\Security" /v "NetworkDtcAccessInbound" /t "REG_DWORD"  /d 1 /f 
reg add "HKLM\SOFTWARE\Microsoft\MSDTC\Security" /v "NetworkDtcAccessOutbound" /t "REG_DWORD"  /d 1 /f 
reg add "HKLM\SOFTWARE\Microsoft\MSDTC\Security" /v "NetworkDtcAccessTip" /t "REG_DWORD"  /d 0 /f 
reg add "HKLM\SOFTWARE\Microsoft\MSDTC\Security" /v "NetworkDtcAccessTransactions" /t "REG_DWORD"  /d 1 /f 
reg add "HKLM\SOFTWARE\Microsoft\MSDTC\Security" /v "XaTransactions" /t "REG_DWORD"  /d 1 /f 
reg add hklm\software\policies\microsoft\windows\windowsupdate\au /v AlwaysAutoRebootAtScheduledTime /t REG_DWORD /d "1" /f

if ($myserver.servername -match '\d{2}up')
{
    reg add "HKLM\SOFTWARE\Microsoft\Rpc\Internet" /v "PortsInternetAvailable" /t "REG_SZ" /d Y /f 
    reg add "HKLM\SOFTWARE\Microsoft\Rpc\Internet" /v "UseInternetPorts" /t "REG_SZ" /d Y /f 
    reg add "HKLM\SOFTWARE\Microsoft\Rpc\Internet" /v "Ports" /t "REG_MULTI_SZ" /d 5000-5200 /f 
}

logger 'install rds server complete.'

########################################################  

copy-item ($configpath + 'scripts\mgmtstudio.ps1') -Destination c:\us\ -force
copy-item ($configpath + 'scripts\2019 SSRS Configuration Script.ps1') -Destination c:\us\ -force


reg add "hklm\software\microsoft\windows\currentversion\runonce" /v install /t reg_sz /d "c:\windows\system32\windowspowershell\v1.0\powershell.exe c:\us\mgmtstudio.ps1" /f

restart-computer -force