
function get-omenicAddress
{
    [CmdletBinding()]
    param
    (
        [parameter(parametersetname = 'ByIPAddress', mandatory)]
        [validatepattern("^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$")]
        $ipaddress,
        [parameter(parametersetname = 'ByServiceTag', mandatory)]
        $Servicetag
        
    )
    
    $alluri = "https://$($server)/api/DeviceService/Devices?" + '$top=5000'
    $mydate = get-date

    if($alldevices -eq $Null)
    {
        $script:alldevices = invoke-restmethod -uri $alluri -ContentType 'application/json' -method Get -websession $mysess
        $alldevices | Add-Member -NotePropertyName timeset -notepropertyvalue $mydate
    }
    elseif($mydate -gt $alldevices.timeset.addminutes(5))
    {
        $script:alldevices = invoke-restmethod -uri $alluri -ContentType 'application/json' -method Get -websession $mysess
        $alldevices | Add-Member -NotePropertyName timeset -notepropertyvalue $mydate
    }
    
    if($ipaddress -ne $Null)
    {   
        $Mydevice = $alldevices.value | where{$_.devicemanagement.networkaddress -eq "$ipaddress"}
        $collection = @()
        if($mydevice -ne $Null)
        {
            $inventoryuri = "https://$($server)$($mydevice | select -expand InventoryDetails@odata.navigationLink)"
            $nicinfo = ((invoke-restmethod -uri $inventoryuri -method Get -ContentType 'application/json' -websession $mysess).value | where{$_.inventorytype -match 'NetworkInterfaces'}).inventoryinfo.ports
            $collection = @()

            foreach ($nic in $nicinfo)
            {
                
                $mynic = new-object psobject -Property `
                @{
                
                    IPAddress = $ipaddress
                    ProductName = ($nic.productname.split('-')[0])
                    PortID = ($nic.portid)
                    Macaddress = ($nic.productname.split('-')[1]).trimstart()
                } | select ipaddress,Productname,portid,macaddress

                $collection += $mynic
                
            }

            write-output $collection
            write-host "`n"
        }
        else
        {
            throw "$ipAddress was not Found in OME"
        }
    }
    elseif($servicetag -ne $Null)
    {
        $Mydevice = $alldevices.value | where{$_.identifier -eq "$servicetag"}
        $collection = @()
        if($mydevice -ne $Null)
        {
            $inventoryuri = "https://$($server)$($mydevice | select -expand InventoryDetails@odata.navigationLink)"
            $nicinfo = ((invoke-restmethod -uri $inventoryuri -method Get -ContentType 'application/json' -websession $mysess).value | where{$_.inventorytype -match 'NetworkInterfaces'}).inventoryinfo.ports
            $collection = @()

            foreach ($nic in $nicinfo)
            {
                
                $mynic = new-object psobject -Property `
                @{
                
                    servicetag = $servicetag
                    ProductName = ($nic.productname.split('-')[0])
                    PortID = ($nic.portid)
                    Macaddress = ($nic.productname.split('-')[1]).trimstart()
                } | select servicetag,Productname,portid,macaddress

                $collection += $mynic
                
            }

            write-output $collection
            write-host "`n"
        }
        else
        {
            throw "$servicetag was not Found in OME"
        }
    }


}