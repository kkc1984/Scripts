get-service termservice | stop-service -force

$configpath = get-content c:\windows\temp\config.txt
$myserver = import-csv ($configpath + 'ServerConfig\' + $env:computername + '.csv')
reg add "hklm\software\microsoft\windows\currentversion\runonce" /v install /t reg_sz /d "c:\windows\system32\windowspowershell\v1.0\powershell.exe c:\us\hbe2.ps1" /f

function logger
{
    param($message)
    $message + ' ' + (get-date).ToShortDateString() + ' ' + (get-date).ToShortTimeString() | out-file ($configpath + 'ServerLogs\' + $env:computername + '.txt') -append 
}

if("$env:computername" -like "*hbe*")
{
    logger 'installing external disk cache for hbe type server.'
    msiexec /i C:\us\downloads\ExternalDiskCache_amd64_en-US.msi /passive /norestart /l c:\external.txt
    sleep 60
    logger 'installtion complete.'
}

restart-computer -force