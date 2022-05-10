
function Create-omeGroup
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        $groupname
    )

    $StaticGrp   = "https://$($server)/api/GroupService/Groups?`$filter=Name eq 'Static Groups'"
    $response = invoke-restmethod -uri $StaticGrp -ContentType 'application/json' -websession $mysess
    $Create= "https://$($server)/api/GroupService/Actions/GroupService.CreateGroup"

    $groupinfo = @{
        "Name"=$GroupName;
        "Description"="";
        "MembershipTypeId"=12;
        "ParentId"=[uint32]$response.value[0].id
    }

    $payload = @{"GroupModel"=$groupinfo} | ConvertTo-Json

    Invoke-RestMethod -Uri $create -Method Post -ContentType 'application/json' -Body $payload -websession $mysess
    write-host "Added $groupname" -f yellow
}