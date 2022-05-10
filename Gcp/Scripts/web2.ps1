get-service termservice | stop-service -force

$configpath = get-content c:\windows\temp\config.txt
$myserver = import-csv ($configpath + 'ServerConfig\' + $env:computername + '.csv')
function logger
{
    param($message)
    $message + ' ' + (get-date).ToShortDateString() + ' ' + (get-date).ToShortTimeString() | out-file ($configpath + 'ServerLogs\' + $env:computername + '.txt') -append 
}

reg add "hklm\software\microsoft\windows\currentversion\runonce" /v install /t reg_sz /d "c:\windows\system32\windowspowershell\v1.0\powershell.exe c:\us\hbeexternal.ps1" /f

if("$env:computername" -match "up\d\dwb|hbe")
{
    logger 'installing rewrite package for web/hbe server'
    msiexec /i C:\us\downloads\rewrite_amd64_en-US.msi /passive /norestart /l c:\rewrite.txt
    sleep 120
    logger 'installtion complete.'
}      

restart-computer -force
