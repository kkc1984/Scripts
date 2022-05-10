
function get-omediscovery
{
    [cmdletbinding()]
    param
    (
        [parameter(parametersetname = 'ByAll')]
        [switch]$all,
        [parameter(parametersetname = 'ByName')]
        $name
        
    )
    
    $uri = "https://$($server)/api/DiscoveryConfigService/Jobs"

    $alldiscovery = invoke-restmethod -uri $uri -ContentType 'application/json' -method get -websession $mysess
    
    function add-prop
    {
        param
        (
            $object,
            $prop
        )

        $object |  Add-Member -NotePropertyName 'JobName' -NotePropertyValue $prop.JobName -force
        $object |  Add-Member -NotePropertyName 'JobStartTime' -NotePropertyValue $prop.JobStartTime -force
        $object |  Add-Member -NotePropertyName 'JobEndTime' -NotePropertyValue $prop.JobEndTime -force
        $object |  Add-Member -NotePropertyName 'JobProgress' -NotePropertyValue $prop.JobProgress -force
        $object |  Add-Member -NotePropertyName 'JobEnabled' -NotePropertyValue $prop.JobEnabled -force
        $object |  Add-Member -NotePropertyName 'JobNextRun' -NotePropertyValue $prop.JobNextRun -force
        $object |  Add-Member -NotePropertyName 'DiscoveredDevicesByType' -NotePropertyValue $prop.DiscoveredDevicesByType -force
        $object |  Add-Member -NotePropertyName 'DiscoveryConfigExpectedDeviceCount' -NotePropertyValue $prop.DiscoveryConfigExpectedDeviceCount -force
        $object |  Add-Member -NotePropertyName 'DiscoveryConfigDiscoveredDeviceCount' -NotePropertyValue $prop.DiscoveryConfigDiscoveredDeviceCount -force
        

    }
    ##################################################################


    
##############################################################
    if($all -eq $true )
    {
        foreach($item in $alldiscovery.value)
        {
            $myobject = new-object -TypeName psobject

            add-prop -object $myobject -prop $item
            
            $myobject 
            
            

        }
    }
       
    
    if($name -ne $Null)
    {
        $mydevice = $alldiscovery.value | where{$_.jobname -eq "$name"}

        if($mydevice -ne $null)
        {
            $myobject = new-object -TypeName psobject

            add-prop -object $myobject -prop $mydevice
            
            $myobject 
        }
        else 
        {
            Throw "Discovery Job $name Was not Found!"
        }
    }



}