
function get-omegroupdevices
{
    [cmdletbinding()]
    param
    (
        [parameter(parametersetname = 'byGroup',mandatory)]
        $groupname,
        [parameter(parametersetname = 'byAllGroups')]
        [switch]$Listgroups

    )

    $StaticGrp   = "https://$($server)/api/GroupService/Groups?" + '$top=500'
    $response = invoke-restmethod -uri $staticgrp -ContentType 'application/json' -method get -websession $mysess
    
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

    }

    if($listgroups -eq $true)
    {
        $groups = $response.value | where{$_.createdby -ne 'system'}
        foreach($item in $groups)
        {
            write-output "$($item.name)"
        }
    }
    else 
    {
        $mygroup = $response.value | where{$_.name -eq "$groupname"}
        $uri = "https://$($server)/api/GroupService/Groups($($mygroup.id))/AllLeafDevices"

        $alldevices  = invoke-restmethod -uri $uri -ContentType 'application/json' -websession $mysess -method Get

        foreach($item in $alldevices.value)
        {
            
            $myobject = new-object -TypeName psobject

            add-prop -object $myobject -prop $item
            
            $myobject 
            
        

        }
    }

}