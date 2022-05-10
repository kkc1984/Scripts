
function remove-omegroup
{
    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true, mandatory)]
        $groupname
    )

    $StaticGrp = "https://$($server)/api/GroupService/Groups?" + '$top=500'
    $response = invoke-restmethod -uri $StaticGrp -ContentType 'application/json' -websession $mysess
    $mygroup = $response.value | where{$_.name -eq "$groupname"}
    $uri = "https://$($server)/api/GroupService/Actions/GroupService.DeleteGroup"


        $groupinfo = @{
            "GroupIds"='[' + $mygroup.id + ']'
        }

        $payload = $groupinfo| convertto-json 
        $payload = $payload.Replace('"[','[').replace(']"',']')
        invoke-restmethod -uri $uri -method Post -ContentType 'application/json' -body $payload -websession $mysess

        write-host "Removed $groupname" -f yellow

}