$computers = import-csv D:\kevinc\gcpdecom\computers.csv
$mydate = get-date -format G

foreach($item in $computers)
{
    $dbobj = invoke-sqlcmd -Database exampledb -query "Select * from exampleconfig where servername = '$($item.servername)'"
    if($dbobj)
    {
        try
        {
            $item | add-member -NotePropertyName 'cluster' -NotePropertyValue ($($dbobj.clustername)).replace('-','')
        }
        catch
        {
            $item | add-member -NotePropertyName 'cluster' -NotePropertyValue ''
        }
    
    }
    if(!($item.project))
    {
        $item.project = $dbobj.project
    }
    
}

$computers | ft
pause

foreach($item in $computers)
{
    write-host "_____________________" -f yellow
    write-host "∙$($item.servername)∙" -f green
    write-host "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯" -f yellow
    ############################### getting gcloud instance
    $instance = Get-GceInstance -project $item.project | where{$_.name -match "^$($item.servername)$"}

    if($instance -match '[a-zA-Z]')
    {
        ###########################setting variables 
        switch (hostname)
        {
            'vm1'{$domain = 'dom1'; $vpc_Project = 'proj1'; $dns = 'dns1'}
            'vm2'{$domain = 'dom2'; $vpc_Project = 'proj2'; $dns = 'dnsq2'  }
            'vm3'{$domain = 'dom3'; $vpc_Project = 'proj3'; $dns = 'dns3' }
        }

        $subnet = $instance.NetworkInterfaces.subnetwork
        $region = ($subnet | select-string -pattern "$($vpc_project)/.*/subnetworks" | %{ $_.Matches[0].value}).split('/').trimend()[-2]
        $zone = ($instance.zone).split('/')[-1]
        $project = $item.project
        $servername = $item.servername
        $jira = $item.jira
        $xdrive = $Item.xdrive

        

        ############################Deleting instance and deleting AD object 
        
        write-host "Disabling Deletion Portection and Deleting Instance" -f Cyan
        
        if($xdrive -match 'y')
        {    
            $delete = ($instance).disks | ? {$_.source -match '-x$|-vol4$'}
            if($delete)
            {
                gcloud compute instances set-disk-auto-delete $servername --project=$project --disk=$($delete.source) --zone=$zone
            }
            
        }
        
        gcloud compute instances update $($servername) --no-deletion-protection --zone=$zone --project=$($project)
        $instance | remove-gceinstance -Verbose

        $reservation = gcloud compute addresses list --regions=$($region) --project=$($project) --filter="name:$($servername)" | select-string "$($servername)"
        if($reservation -match '[a-zA-Z]')
        {
            write-host "Reservation found Deleting..." -f cyan
            foreach($item in $reservation)
            {
                gcloud compute addresses delete ($item.tostring().split(' ')[0]) --region=$($region) --project=$($project) --quiet
            }
            
        }
        else
        {
            write-host "No Reservation Found" -f cyan
        }

        ################################# Checking for clusterobj in AD/LoadB IP and Access point IP to delete
        if($item.cluster -match '[a-zA-Z]')
        {

            $clustername = $item.cluster
            
            
            if($clustername -match '[a-zA-Z]')
            {
                $clustername = $clustername.tolower()
                $item | add-member -NotePropertyName 'clustername' -NotePropertyValue $clustername
                write-host "Checking for Cluster objects..." -f cyan
                $clusterobj = get-adcomputer -server $domain -filter "name -eq '$($clustername)'"

                if($clusterobj)
                {
                    write-host "cluster object found deleting..." -f Yellow
                    $clusterobj
                    $clusterobj | Set-ADObject -ProtectedFromAccidentalDeletion:$false -Verbose
                    $clusterobj | Remove-ADObject -confirm:$false -Verbose
                }

                $mainrec = Get-DnsServerResourceRecord -zonename $domain -computername $dns -rrtype a | where {$_.hostname -match "^$($clustername)$"}
                if ($mainrec -ne $Null)
                {
                    $mainrec | Remove-DnsServerResourceRecord -Force -zonename $domain -ComputerName $dns -Verbose
                }

                $clcheck = gcloud compute addresses list --filter="region:( $($region) )" --project=$($project) | select-string "$($clustername)"
                
                if($clcheck.count -ne 0)
                {
                    foreach($item in $clcheck)
                    {
                        gcloud compute addresses delete ($item.tostring().split(' ')[0]) --region=$($region) --project=$($project) --quiet
                    }
                }

            

                $backend = gcloud compute backend-services list --project=$($project) --regions=$($region) | select-string "$($clustername)" 

                if($backend.count -gt 0)
                {
                    foreach($back in $backend)
                    {
                        $forwarding = gcloud compute forwarding-rules list --project=$($project) --regions=$($region) | select-string "$($back.tostring().split('')[0])"
                        if($forwarding.count -gt 0)
                        {
                            foreach($item in $forwarding)
                            {
                                gcloud compute forwarding-rules delete ($item.tostring().split(' ')[0]) --project=$($project) --region=$($region) --quiet
                            }
                        }

                        gcloud compute backend-services delete $($back.tostring().split('')[0]) --project=$($project) --region=$($region) --quiet
                    }
                    
                    
                }

                $groups = gcloud compute instance-groups unmanaged list --filter="name:$($clustername)-group*" --project=$($project) | select-string "$($clustername)-group-"

                if($groups.count -ne 0)
                {
                    gcloud compute instance-groups unmanaged delete $($groups[0].tostring().split('')[0]) --project=$($project) --quiet --zone=$($zone)
                }
        

                write-host "$($servername): Object Decommed" -f yellow

            }
            else
            {
                Write-host "$($servername) Cluster NOT FOUND"
            }
        }

        write-host "Deleting Ad Computer Object" -f Cyan
        $compobj = get-adcomputer -server $domain -filter "name -eq '$($servername)'"
        
        if($compobj)
        {
            write-host "computer object found deleting..." -f Yellow
            $compobj
            $compobj | Remove-ADObject -confirm:$false -Verbose
        }
        
        write-host "Checking and deleting Main DNS Record..." -f Cyan
        $mainrec = Get-DnsServerResourceRecord -zonename $domain -computername $dns -rrtype a | where {$_.hostname -match "^$($servername)$"}
        if ($mainrec -ne $Null)
        {
            $mainrec | Remove-DnsServerResourceRecord -Force -zonename $domain -ComputerName $dns -Verbose
        }

        write-host "$($servername): Vm,Computer object, and Dns Entries Decommed" -f yellow
        
        $hostname = $env:COMPUTERNAME
        switch -regex ($hostname)
        {
            'vm1'{$fileserver = 'fs1'}
            'vm2'{$fileserver = 'fs2'}
            'vm3'{$fileserver = 'fs3'}
        }

        write-host "Checking for quorum folder" -f Cyan
        
        if(test-path ($fileserver + $($clustername) + '-quorum'))
        {
            remove-item ($fileserver + $($clustername) + '-quorum') -Recurse -force -Verbose
        }

    }
    else
    {
        write-host "$($servername) NOT FOUND" -f red
    }

    ######################## update serverconfig table
    $chk = invoke-sqlcmd -Database exampledb -query "select * from exampleconfig where servername = '$($servername)'"

    if($chk)
    {
        invoke-sqlcmd -Database gcpservers -query "update exampleconfig set decomjira = '$($jira)', decomdate = '$($mydate)', Active = 'False' where servername = '$($servername)'"
    }

    write-host "=======$($servername) DECOM COMPLETE ==========" -f yellow
    
}




