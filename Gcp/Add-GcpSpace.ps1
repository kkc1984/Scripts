function Add-GcpSpace 
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        $project,
        [parameter(Mandatory)]
        $name,
        [parameter(Mandatory)]
        $driveletter,
        [parameter(Mandatory)]
        $size
        
    )
    cls
    $vm = get-gceinstance -project $project | where{$_.name -match "^$($name)$"}
    if($vm -ne $Null)
        {
        $disks = get-gcedisk -project $project | where{$_.selflink -match $($name)}
    
        $Myhash = @{}
        $myhash.clear()
        $myarray = $vm.disks.source

        write-host "Requsted Size Increase: $size" -f cyan
        write-host "Select Disk to Expand:" -f yellow
        for($i=1;$i -le $Myarray.count; $i++)
        {
                    
            write-host "$i. $($myarray[$i-1].split('/')[-1]) " `
            (($disks | where{$_.selflink -match "^$($myarray[$i-1])$"})).sizeGB"GB"  -f green
            $myhash.add($i,$myarray[$i-1])
        }

        write-host "Enter Selection (1,2,3,4,5):" -f yellow
        [int]$answer = read-host
    
        $newsize = ($disks | where{$_.selflink -match "^$($myhash[$answer])$"}).SizeGb + $size
        write-host "New Drive Size: $($newsize)" -f cyan

        ($disks | where{$_.selflink -match "^$($myhash[$answer])$"}) | Resize-GceDisk -NewSizeGb $newsize

        invoke-command -computername $name -ScriptBlock `
        {
            param($driveletter)
            "rescan","sel vol $($driveletter)","extend" | diskpart
        } -ArgumentList $driveletter
    }
    else
    {
        Write-error "$($name) NOT FOUND!"
    }
}