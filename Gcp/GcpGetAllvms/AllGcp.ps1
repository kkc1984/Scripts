$all = (get-gcpproject).projectid
$vmlist = @()

foreach($project in $all)
{
    write-host "Working on $project" -f yellow
    write-host "-----------------------" -f yellow
    $instances = get-gceinstance -project $project | select @{n="Name";e={$_.name}},@{n="Zone";e={($_.Zone).split('/')[-1]}},@{n="Labels";e={$_.labels.values -join ","}},@{n="Project";e={$project}}
    $vmlist += $instances
}

$vmlist | export-csv D:\kevinc\GcpGetAllvms\allvms.csv -NoTypeInformation 