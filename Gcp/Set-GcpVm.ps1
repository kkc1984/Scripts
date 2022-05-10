function Set-GcpVm
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        $Project,
        [parameter(Mandatory)]
        $Name,
        $numcpu,
        $memoryGB,
        $series
        
    )

    $Myvm = get-gceinstance -project $project | where{$_.name -match $($name)}
    
    if($myvm -ne $Null)
    {
        write-host "Changing Config On $($name)" -f yellow
        $zone = ($myvm.zone).split('/')[-1]
        $status = $myvm.status
        $originaltype = (($myvm.MachineType).split('/')[-1]).split('-')
        
        
        if($series)
        {
            $type = "--custom-vm-type=$($series)"
        }
        else
        {
            if($originaltype[0] -notmatch 'custom')
            {
                $type = "--custom-vm-type=$($originaltype[0])"
            }
        }

        if($numcpu)
        {
            $totalcpu = "--custom-cpu=$($numcpu)"
        }
        if($memoryGB)
        {
            $totalmem = "--custom-memory=$($memoryGB)"
        }

        if($myvm.status -match 'running')
        {
            $myvm | Stop-GceInstance | out-null
        }
        
        gcloud compute instances update $($name) --min-cpu-platform="automatic" --project=$($project) --zone=$($zone)
        gcloud compute instances set-machine-type $name $($totalcpu) $($totalmem) $($type) --project=$($project) --zone=$($zone)

        if($myvm.status -match 'running')
        {
            $myvm | start-GceInstance 
        }
    }
    else
    {
        Write-error "$($name) NOT FOUND!"
    }     

}