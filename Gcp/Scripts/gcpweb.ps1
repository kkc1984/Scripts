get-service termservice | stop-service -force

$configpath = get-content c:\windows\temp\config.txt
$myserver = import-csv ($configpath + 'ServerConfig\' + $env:computername + '.csv')

function logger
{
    param($message)
    $message + ' ' + (get-date).ToShortDateString() + ' ' + (get-date).ToShortTimeString() | out-file ($configpath + 'ServerLogs\' + $env:computername + '.txt') -append 
}



logger 'installing IIS...' 

start-process -nonewwindow -wait dism.exe -argumentlist `
"/enable-feature /online /featureName:IIS-WebServerRole /featureName:IIS-WebServer /featureName:IIS-CommonHttpFeatures /featureName:IIS-StaticContent /featureName:IIS-DefaultDocument /featureName:IIS-DirectoryBrowsing /featureName:IIS-HttpErrors /featureName:IIS-ApplicationDevelopment /featureName:IIS-ASPNET45 /featureName:IIS-NetFxExtensibility45 /featureName:IIS-ASP /featureName:IIS-ISAPIExtensions /featureName:IIS-ISAPIFilter /featureName:IIS-HealthAndDiagnostics /featureName:IIS-HttpLogging /featureName:IIS-LoggingLibraries /featureName:IIS-RequestMonitor /featureName:IIS-HttpTracing /featureName:IIS-CustomLogging /featureName:IIS-Security /featureName:IIS-BasicAuthentication /featureName:IIS-WindowsAuthentication /featureName:IIS-RequestFiltering /featureName:IIS-Performance /featureName:IIS-HttpCompressionStatic /featureName:IIS-HttpCompressionDynamic /featureName:IIS-WebServerManagementTools /featureName:IIS-ManagementScriptingTools /featureName:IIS-ManagementService /featureName:NetFx4Extended-ASPNET45 /featureName:IIS-ManagementConsole"

start-process -nonewwindow -wait dism.exe -argumentlist `
"/disable-feature /online /featureName:IIS-IIS6ManagementCompatibility /featureName:IIS-Metabase /featureName:IIS-LegacySnapIn /featureName:IIS-LegacyScripts /featureName:IIS-WMICompatibility"

start-process -nonewwindow -wait dism.exe -argumentlist `
"/Online /Enable-Feature /FeatureName:WCF-HTTP-Activation /all"

start-process -nonewwindow -wait dism.exe -argumentlist `
"/Online /Enable-Feature /FeatureName:WCF-HTTP-Activation45"


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
        
mkdir c:\us\downloads
copy-item ($configpath + 'scripts\web2.ps1') -Destination c:\us\ -force
copy-item ($configpath + 'scripts\hbeexternal.ps1') -Destination c:\us\ -force
copy-item ($configpath + 'scripts\hbe2.ps1') -Destination c:\us\ -force
copy-item -path ($configpath + 'downloads\web\*') -Destination C:\us\downloads\

reg add "hklm\software\microsoft\windows\currentversion\runonce" /v install /t reg_sz /d "c:\windows\system32\windowspowershell\v1.0\powershell.exe c:\us\web2.ps1" /f

logger 'installation complete'
 
if("$env:computername" -like "*hbe*")
{
    
    if($myserver.os -eq '2019')
    {
        reg add hklm\software\microsoft\inetstp /v MajorVersion /t "REG_DWORD" /d 9 /f
        reg add hklm\SYSTEM\CurrentControlSet\Services\W3SVC\Parameters /v MajorVersion /t "REG_DWORD" /d 9 /f
    }
    logger 'Installing webfarm for hbe type server...'
    do
    {

        
        sleep 10

        msiexec /i C:\us\downloads\webfarm_v1.1_amd64_en_us.msi /passive /norestart /l c:\webfarm.txt
        sleep 60
        $webtest = get-content C:\webfarm.txt
    }
    while(($webtest | select-string "Installation completed successfully") -eq $Null)
    logger 'webfarm installed.'
}
 

restart-computer -force
