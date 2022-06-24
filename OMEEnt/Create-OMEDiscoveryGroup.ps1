
function Create-omediscoverygroup
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        $name,
        [parameter(Mandatory)]
        $subnet,
        [switch]$scheduled,
        [switch]$runnow,
        $communitystring,
        $user,
        $password


    )

    #$StaticGrp   = "https://$($server)/api/GroupService/Groups?`$filter=Name eq 'Static Groups'"
    #$response = invoke-restmethod -uri $StaticGrp -ContentType 'application/json' -websession $mysess
    $Create= "https://$($server)/api/DiscoveryConfigService/DiscoveryConfigGroups"

    $payload = '{
            "DiscoveryConfigGroupName":"Server Discovery",
            "DiscoveryConfigModels":[
                {
                 "DiscoveryConfigTargets":[
				 {
						  "NetworkAddressDetail":"",
                          "AddressType":  30
                     }
                 ],
                "ConnectionProfile":"{
                    \"profileName\":\"\",
                    \"profileDescription\":\"\",
                    \"type\":\"DISCOVERY\",
                    \"credentials\":[{
                        \"type\":\"WSMAN\",
                        \"authType\":\"Basic\",
                        \"modified\":false,
                        \"credentials\": {
                            \"username\":\"\",
                            \"password\":\"\",
                            \"caCheck\":false,
                            \"cnCheck\":false,
                            \"port\":443,
                            \"retries\":3,
                            \"timeout\": 60
                        }
                    },
                    {
                        \"type\":\"REDFISH\",
                        \"authType\":\"Basic\",
                        \"modified\":false,
                        \"credentials\": {
                            \"username\":\"\",
                            \"password\":\"\",
                            \"caCheck\":false,
                            \"cnCheck\":false,
                            \"port\":443,
                            \"retries\":3,
                            \"timeout\": 60
                        }
                    },
                    {
                        \"type\":\"SNMP\",
                        \"authType\":\"Basic\",
                        \"modified\":false,
                        \"credentials\":{
                            \"community\":\"public\",
                            \"enableV1V2\":true,
                            \"port\":161,
                            \"retries\":3,
                            \"timeout\":3
                        }
                    }]
                }",
                "DeviceType":[1000,2000,5000,7000]
                }],
            "Schedule":{
                "RunNow":true,
                "RunLater":false,
                "Cron":"startnow"
            },
            "CreateGroup":false,
            "TrapDestination":true,
            "CommunityString":true
    }' | ConvertFrom-Json
    

    
    $Payload.DiscoveryConfigGroupName = $Name
    
    #if ($Email) 
    #{
    #    $Payload.DiscoveryStatusEmailRecipient = $Email
    #} else 
    #{
    #    $Payload.DiscoveryStatusEmailRecipient.PSObject.Properties.Remove("DiscoveryConfigTargets")
    #}

    #if ($SetTrapDestination)
    #{
    #    $Payload.TrapDestination = $true
    #}
    #if ($SetCommunityString)
    #{
    #    $Payload.CommunityString = $true
    #}
    
    
    #if ($UseAllProtocols) 
    #{
    #    $Payload | Add-Member -NotePropertyName UseAllProfiles -NotePropertyValue $true
    #}
    
    $Payload.DiscoveryConfigModels[0].PSObject.Properties.Remove("DiscoveryConfigTargets")
    $Payload.DiscoveryConfigModels[0]| Add-Member -MemberType NoteProperty -Name 'DiscoveryConfigTargets' -Value @()
    foreach ($DiscoveryHost in $subnet)
    {
        $jsonContent = [PSCustomObject]@{
            "AddressType" = 30
            "NetworkAddressDetail" = $DiscoveryHost
        }
        
        $Payload.DiscoveryConfigModels[0].DiscoveryConfigTargets += $jsonContent
    }

    
    
    $ConnectionProfile = $Payload.DiscoveryConfigModels[0].ConnectionProfile | ConvertFrom-Json
    $ConnectionProfile.credentials[0].credentials.'username' = $User
    $ConnectionProfile.credentials[0].credentials.'password' = $Password
    $ConnectionProfile.credentials[1].credentials.'username' = $User
    $ConnectionProfile.credentials[1].credentials.'password' = $Password

    if($communitystring)
    {
        $ConnectionProfile.credentials[2].credentials.community = $communitystring
    }

    $Payload.DiscoveryConfigModels[0].ConnectionProfile = $ConnectionProfile | ConvertTo-Json -Depth 6
    

    if ("scheduled") 
    {
        $ScheduleCron = "0 7 8 * * ? *"
        $Payload.Schedule.RunNow = $false
        $Payload.Schedule.RunLater = $true
        $Payload.Schedule.Cron = $ScheduleCron
    }
    elseif($runnow)
    {
        $Payload.Schedule.RunNow = $true
        $Payload.Schedule.RunLater = $false
        $Payload.Schedule.Cron = "startnow"
    }

    Invoke-RestMethod -Uri $create -Method Post -ContentType 'application/json' -Body ($Payload | convertto-json -Depth 6) -websession $mysess -Verbose
    
}

