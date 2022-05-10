
function get-omedevice
{
    [cmdletbinding()]
    param
    (
        [parameter(parametersetname = 'ByAll')]
        [switch]$all,
        [parameter(parametersetname = 'ByServiceTag')]
        $servicetag,
        [parameter(parametersetname = 'ByIpAddress')]
        [validatepattern("^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$")]
        $ipAddress,
        [parameter(parametersetname = 'ByName')]
        $name
        
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
    
    function add-prop
    {
        param
        (
            $object,
            $prop
        )

        $object |  Add-Member -NotePropertyName 'ServiceTag' -NotePropertyValue $prop.identifier -force
        $object |  Add-Member -NotePropertyName 'Model' -NotePropertyValue $prop.Model -force
        $object |  Add-Member -NotePropertyName 'Devicename' -NotePropertyValue $prop.Devicename -force
        $object |  Add-Member -NotePropertyName 'IDracName' -NotePropertyValue $prop.devicemanagement.dnsname -force
        $object |  Add-Member -NotePropertyName 'IPAddress' -NotePropertyValue $prop.devicemanagement.networkaddress -force
        $object |  Add-Member -NotePropertyName 'ConnectionState' -NotePropertyValue $prop.Connectionstate -force
        $object |  Add-Member -NotePropertyName 'ChassisServiceTag' -NotePropertyValue $prop.ChassisServiceTag -force
        $object |  Add-Member -NotePropertyName 'DeviceId' -NotePropertyValue $prop.Id -force


    }
    ##################################################################

    if($ipaddress -ne $null)
    {
        
        
        $mydevice = $alldevices.value | where{$_.devicemanagement.networkaddress -eq "$ipaddress"}
        if($mydevice -ne $null)
        {
            $myobject = new-object -TypeName psobject

            add-prop -object $myobject -prop $mydevice
            
            $myobject
        }    
        else 
        {
            Throw "IPAddress $ipaddress Was not Found!"
        }

    }
    
##########################################################

    if($servicetag -ne $null)
    {
        $mydevice = $alldevices.value | where{$_.identifier -eq "$servicetag"}

        if($mydevice -ne $null)
        {
            $myobject = new-object -TypeName psobject

            add-prop -object $myobject -prop $mydevice
            
            $myobject
        }    
        else 
        {
            Throw "ServiceTag $servicetag Was not Found!"
        }
        
        
    }
    
##############################################################
    if($name -ne $null)
    {
        $mydevice = $alldevices.value | where{$_.devicename -match "$name" -or $_.devicemanagement.dnsname -match $name}

        if($mydevice -ne $null)
        {
            $myobject = new-object -TypeName psobject

            add-prop -object $myobject -prop $mydevice
            
            $myobject
        }    
        else 
        {
            Throw "Name $Name Was not Found!"
        }
        
        
    }
    
    
##############################################################
    if($all -eq $true )
    {
        foreach($item in $alldevices.value)
        {
            $myobject = new-object -TypeName psobject

            add-prop -object $myobject -prop $item
            
            $myobject 
            
            

        }
    }
        


}

