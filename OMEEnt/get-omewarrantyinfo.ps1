function get-omewarrantyinfo
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
        $name,
        [parameter(parametersetname = 'ByAll')]
        [switch]$email
        
    )


    function add-prop
    {
        param
        (
            $object,
            $prop,
            $warprop
        )

        $object |  Add-Member -NotePropertyName 'ServiceTag' -NotePropertyValue $prop.identifier -force
        $object |  Add-Member -NotePropertyName 'DeviceModel' -NotePropertyValue $prop.Model -force
        $object |  Add-Member -NotePropertyName 'Devicename' -NotePropertyValue $prop.Devicename -force
        $object |  Add-Member -NotePropertyName 'ShippedDate' -NotePropertyValue ("{0:MM/dd/yy}" -f [datetime]$warprop.SystemShipDate) -force
        $object |  Add-Member -NotePropertyName 'WarrantyEndDate' -NotePropertyValue ("{0:MM/dd/yy}" -f [datetime]$warprop.EndDate) -force
        $object |  Add-Member -NotePropertyName 'DaysRemaining' -NotePropertyValue $warprop.DaysRemaining -force
        
        if($server -eq '10.146.16.14')
        {
            $object |  Add-Member -NotePropertyName 'DataCenter' -NotePropertyValue 'devLV'-force
        }
        elseif($server -eq '10.147.16.60')
        {
            $object |  Add-Member -NotePropertyName 'DataCenter' -NotePropertyValue 'LASSAAS'-force
        }
    }

    $warrantyuri = "https://$($server)/api/WarrantyService/Warranties?" + '$top=10000'
    $warranty = invoke-restmethod -uri $warrantyuri -ContentType 'application/json' -method get -websession $mysess
    $deviceuri = "https://$($server)/api/DeviceService/Devices?" + '$top=5000'
    $alldevices = invoke-restmethod -uri $deviceuri -ContentType 'application/json' -method get -websession $mysess
    
    if($ipaddress -ne $null)
    {
        
        
        $mydevice = $alldevices.value | where{$_.devicemanagement.networkaddress -eq "$ipaddress"}
        if($mydevice -ne $null)
        {
            $mywarranty = $warranty.value | where { $_.DeviceIdentifier -eq $($mydevice.Identifier)} | select -last 1
            $myobject = new-object -TypeName psobject

            add-prop -object $myobject -prop $mydevice -warprop $mywarranty
            
            $myobject | select-object DeviceName,ServiceTag,DeviceModel,ShippedDate,WarrantyEndDate,DaysRemaining,DataCenter
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
            $mywarranty = $warranty.value | where { $_.DeviceIdentifier -eq $($mydevice.Identifier)} | select -last 1
            $myobject = new-object -TypeName psobject

            add-prop -object $myobject -prop $mydevice -warprop $mywarranty
            
            $myobject | select-object DeviceName,ServiceTag,DeviceModel,ShippedDate,WarrantyEndDate,DaysRemaining,DataCenter
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
            $mywarranty = $warranty.value | where { $_.DeviceIdentifier -eq $($mydevice.Identifier)} | select -last 1
            $myobject = new-object -TypeName psobject

            add-prop -object $myobject -prop $mydevice -warprop $mywarranty
            
            $myobject | select-object DeviceName,ServiceTag,DeviceModel,ShippedDate,WarrantyEndDate,DaysRemaining,DataCenter
        }    
        else 
        {
            Throw "Name $Name Was not Found!"
        }
        
        
    }
    
    
##############################################################
    if($all -eq $true )
    {
       
        $completelist = 
        
        foreach($item in $alldevices.value)
        {
            $mywarranty = $warranty.value | where { $_.DeviceIdentifier -eq $($item.Identifier)} | select -last 1
            $myobject = new-object -TypeName psobject

            add-prop -object $myobject -prop $item -warprop $mywarranty
            
            $myobject | select-object DeviceName,ServiceTag,DeviceModel,ShippedDate,WarrantyEndDate,DaysRemaining,DataCenter
            
            

        }

        $completelist

        if($email -eq $true)
        {
            $completelist | export-csv c:\windows\temp\warrantyinfo.csv -NoTypeInformation -force

            switch($server)
            {
                '10.146.16.14'
                {
                    $from = 'devLV-OME@ultimatesoftware.com'
                    $smtp = 'devmail'
                }
                '10.147.16.60'
                {
                    $from = 'LASSAAS-OME@ultimatesoftware.com'
                    $smtp = 'secmail.us.saas'
                }
            }
            
            send-mailmessage -to cloudserverteam@ultimatesoftware.com -from $from -Attachments c:\windows\temp\warrantyinfo.csv -Subject WarrantyReport -SmtpServer $smtp
        }
    }
        


}



