
function add-omedevicetogroup
{
    [CmdletBinding()]
    param
    (
        [parameter(parametersetname = 'ByIPAddress', mandatory)]
        [validatepattern("^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}$")]
        $ipaddress,
        [parameter(parametersetname = 'ByServiceTag', mandatory)]
        $Servicetag,
        [parameter(mandatory)]
        $groupname
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
    
    $StaticGrp = "https://$($server)/api/GroupService/Groups?" + '$top=500'

    if($response -eq $Null)
    {
        $script:response = invoke-restmethod -uri $StaticGrp -ContentType 'application/json' -websession $mysess
        $response | Add-Member -NotePropertyName timeset -notepropertyvalue $mydate
    }
    elseif($mydate -gt $response.timeset.addminutes(5))
    {
        $script:response = invoke-restmethod -uri $StaticGrp -ContentType 'application/json' -websession $mysess
        $response | Add-Member -NotePropertyName timeset -notepropertyvalue $mydate
    }

       
    
    $mygroup = $response.value | where{$_.name -eq "$groupname"}
    $adddvc = "https://$($server)/api/GroupService/Actions/GroupService.AddMemberDevices"

    if($ipaddress -ne $Null)
    {   
        $Mydevice = $alldevices.value | where{$_.devicemanagement.networkaddress -eq "$ipaddress"}
        
        if($mydevice -ne $Null)
        {
            $groupinfo = @{
                "MemberDeviceIds"='[' + $Mydevice.id + ']';
                "GroupId"=$mygroup.id
            }

            $payload = $groupinfo| convertto-json 
            $payload = $payload.Replace('"[','[').replace(']"',']')
            invoke-restmethod -uri $adddvc -method Post -ContentType 'application/json' -body $payload -websession $mysess
            write-host "Added $ipaddress to $groupname" -f yellow
        }
        else
        {
            throw "$ipAddress was not Found in OME"
        }
    }
    elseif($servicetag -ne $Null)
    {
        $Mydevice = $alldevices.value | where{$_.identifier -eq "$servicetag"}
        
        if($mydevice -ne $Null)
        {

            $groupinfo = @{
                "MemberDeviceIds"='[' + $Mydevice.id + ']';
                "GroupId"=$mygroup.id
            }

            $payload = $groupinfo| convertto-json 
            $payload = $payload.Replace('"[','[').replace(']"',']')
            invoke-restmethod -uri $adddvc -method Post -ContentType 'application/json' -body $payload -websession $mysess
            write-host "Added $servicetag to $groupname" -f yellow
        }
        else
        {
            throw "$servicetag was not Found in OME"
        }
    }


}