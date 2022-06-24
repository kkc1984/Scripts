
Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy Bypass -Force

$driveinfo = import-csv c:\windows\temp\driveimport.csv
$path = 'c:\windows\temp\'

####################################

$drive = $driveinfo[0]
if($drive)
{
    if(test-path ($path + 'T_xsfer.txt'))
    {
        remove-item ($path + 'T_xsfer.txt') -force
    }

    robocopy /E /Z /SEC /V /LOG+:c:\windows\temp\T_xsfer.txt "$($drive.driveletter):\" "$($drive.newletter):\"

    $completionchk = get-content ($path +  'T_xsfer.txt') -tail 20 | `
        select-string "Ended : .*,.*, \d{4} \d{1,2}:\d{2}:\d{2} .{2}" 
    
    while(!($completionchk))
    {
        sleep 10
        $completionchk = get-content ($path +  'T_xsfer.txt') -tail 20 | `
            select-string "Ended : .*,.*, \d{4} \d{1,2}:\d{2}:\d{2} .{2}"
    }

    if($completionchk)
    {
        $myvol = get-volume | where{$_.driveletter -eq "$($drive.driveletter)"}
        $newvol = get-volume | where{$_.driveletter -eq "$($drive.newletter)"}
        $myvol | get-partition | Remove-PartitionAccessPath -AccessPath "$($drive.driveletter):\"
        $newvol | get-partition | Remove-PartitionAccessPath -AccessPath "$($drive.newletter):\"
        $newvol | get-partition | add-PartitionAccessPath -AccessPath "$($drive.driveletter):\"
    }


}



 