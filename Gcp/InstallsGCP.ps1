get-service termservice | stop-service -force
################## must change for dev
$configpath = get-content c:\windows\temp\config.txt
###################################
$myserver = import-csv ($configpath + 'ServerConfig\' + $env:computername + '.csv')

function logger
{
    param($message)
    $message + ' ' + (get-date).ToShortDateString() + ' ' + (get-date).ToShortTimeString() | out-file ($configpath + 'ServerLogs\' + $env:computername + '.txt') -append 
}

logger 'Starting Installs........'

if($Myserver.env -match 'p|t')
{
    switch ($myserver.template)
    {
        'pre'
        {
            copy-item ($configpath + 'scripts\gcppre.ps1') -Destination 'C:\Support Tools\' -force
            invoke-expression -command "& 'C:\Support Tools\gcppre.ps1'"
        }
        'sql'
        {
            copy-item ($configpath + 'scripts\gcpsql.ps1') -Destination 'C:\Support Tools\' -force
            invoke-expression -command "& 'C:\Support Tools\gcpsql.ps1'"
        }
        'site'
        {
            copy-item ($configpath + 'scripts\gcpsite.ps1') -Destination 'C:\Support Tools\' -force
            invoke-expression -command "& 'C:\Support Tools\gcpsite.ps1'"
        }
        'dpm'
        {
            copy-item ($configpath + 'scripts\gcpdpm.ps1') -Destination 'C:\Support Tools\' -force
            invoke-expression -command "& 'C:\Support Tools\gcpdpm.ps1'"
        }
        'web'
        {
            copy-item ($configpath + 'scripts\gcpweb.ps1') -Destination 'C:\Support Tools\' -force
            invoke-expression -command "& 'C:\Support Tools\gcpweb.ps1'"
        }
        'ts'
        {
            copy-item ($configpath + 'scripts\gcpts.ps1') -Destination 'C:\Support Tools\' -force
            invoke-expression -command "& 'C:\Support Tools\gcpts.ps1'"
        }

    }
}
else
{
    switch ($myserver.template)
    {
        'pre'
        {
            copy-item ($configpath + 'scripts\gcppre.ps1') -Destination c:\us\ -force
            invoke-expression -command c:\us\gcppre.ps1
        }
        'sql'
        {
            copy-item ($configpath + 'scripts\gcpsql.ps1') -Destination c:\us\ -force
            invoke-expression -command c:\us\gcpsql.ps1
        }
        'site'
        {
            copy-item ($configpath + 'scripts\gcpsite.ps1') -Destination c:\us\ -force
            invoke-expression -command c:\us\gcpsite.ps1
        }
        'dpm'
        {
            copy-item ($configpath + 'scripts\gcpdpm.ps1') -Destination c:\us\ -force
            invoke-expression -command c:\us\gcpdpm.ps1
        }
        'web'
        {
            copy-item ($configpath + 'scripts\gcpweb.ps1') -Destination c:\us\ -force
            invoke-expression -command c:\us\gcpweb.ps1
        }
        'ts'
        {
            copy-item ($configpath + 'scripts\gcpts.ps1') -Destination c:\us\ -force
            invoke-expression -command c:\us\gcpts.ps1
        }

    }
}