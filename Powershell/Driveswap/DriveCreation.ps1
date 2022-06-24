switch -regex (hostname)
{
    '^e'
    {
        connect-server $env:computername
        
    }
    '^n'
    {
        connect-server $env:computername
        
    }
    '^t'
    {
        connect-server $env:computername
        
    }
}

$mydate = get-date -Format G
get-pssession | remove-pssession
$computers = get-content .\computers.txt

$letters = 'p','q','r'

################remove csv file if exists. 

$chk = get-childitem .\*.csv
if($chk)
{
    Move-Item $chk.pspath -Destination .\Archive\ -Force -Verbose
}
    
###############runspace function
function invoke-runspace 
{
    param($list,$scriptblock)
    
    $runspacepool = [RunspaceFactory]::CreateRunspacepool(1,6)
    $runspacepool.Apartmentstate = 'MTA'
    $runspacepool.open()

    $threads = @()

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    foreach($comp in $list)
    {
        $runspaceobject = [pscustomobject] @{
            runspace= [PowerShell]::Create()
            Invoker = $Null
        }

        $runspaceobject.Runspace.RunSpacePool = $runspacepool
        $runspaceobject.Runspace.AddScript($scriptblock) | out-null
        $runspaceobject.Runspace.Addargument($comp) | out-null
        $runspaceobject.Invoker = $runspaceobject.Runspace.BeginInvoke()
        $threads += $runspaceobject
        $elapsed = $stopwatch.elapsed
        write-host "finished creating runspace for $comp. Elapsed time: $elapsed" -f cyan

    }

    while($threads.Invoker.Iscompleted -contains $false) {}
    $elapsed  = $stopwatch.elapsed
    write-host "all runspaces completed. elapsed time: $elapsed" -f cyan

    $thread_results = @()
    foreach($t in $threads)
    {
        $thread_results += $t.runspace.endinvoke($t.invoker)
        $t.runspace.dispose()

    }

    $runspacepool.close()
    $runspacepool.dispose()
    
    return $thread_results
}

########################check PS Connection

$script = 
{
    param
    (
        $computername
    )
    
    $processes = invoke-command -ComputerName $computername -ScriptBlock{hostname}
    return $processes

}

$checker = invoke-runspace -list $computers -scriptblock $script

try
{
    $err = Compare-Object $computers -DifferenceObject $checker | where{$_.sideindicator -eq '<='}
}catch{}

if($err)
{
    write-host "=================================================`n" -f darkred
    $err.InputObject
    write-host "`n"
    throw 'Could Not connect to Machines above, Please Fix or Exclude and Rerun'
    
}

###############################################shutdown matchines
$shutdown_list = @()
foreach($comp in $computers)
{
    $view = get-view -filter @{name="$comp"} -ViewType virtualmachine
    if($view)
    {
        write-host "Shutting down $($view.name)" -f cyan
        $view.CreateSnapshot_Task('Pre-powerflex','Pre-powerflex',$false,$false)
        $view.ShutdownGuest()
        $shutdown_list += $view

    }
    else
    {
        write-error "Didn't Find $comp to Shutdown"
    }
}


while($shutdown_list.runtime.powerstate -match 'poweredon')
{
    foreach($item in $shutdown_list)
    {
        sleep 1
        $item.UpdateViewData()
        write-host "$($item.name) is $($item.runtime.powerstate)" -f yellow
    }
}

#####################function to change controller to paravirtual

function change-paravirtual
{
    param($view,$control)


    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.DeviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (1)
    $spec.DeviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $spec.DeviceChange[0].Device = New-Object VMware.Vim.ParaVirtualSCSIController
    $spec.DeviceChange[0].Device.SharedBus = $control.SharedBus
    $spec.DeviceChange[0].Device.ScsiCtlrUnitNumber = $control.ScsiCtlrUnitNumber
    $spec.DeviceChange[0].Device.HotAddRemove = $true
    $spec.DeviceChange[0].Device.ControllerKey = $control.controllerkey
    $spec.DeviceChange[0].Device.UnitNumber = $control.unitnumber
    $spec.DeviceChange[0].Device.SlotInfo = New-Object VMware.Vim.VirtualDevicePciBusSlotInfo
    $spec.DeviceChange[0].Device.SlotInfo.PciSlotNumber = $control.slotinfo.PciSlotNumber
    $spec.DeviceChange[0].Device.DeviceInfo = New-Object VMware.Vim.Description
    $spec.DeviceChange[0].Device.DeviceInfo.Summary = $control.DeviceInfo.Summary
    $spec.DeviceChange[0].Device.DeviceInfo.Label = $control.DeviceInfo.label
    $spec.DeviceChange[0].Device.Key = $control.key
    $spec.DeviceChange[0].Device.BusNumber = $control.BusNumber
    $spec.DeviceChange[0].Operation = 'edit'
    $spec.CpuFeatureMask = New-Object VMware.Vim.VirtualMachineCpuIdInfoSpec[] (0)
    $view.ReconfigVM_Task($spec)

    $view.UpdateViewData()
}

################ moving hardisks to sas C drive controller and power back on

foreach($item in $shutdown_list)
{
    $item.UpdateViewData()
    #$iscsi = $item.config.hardware.device | where{$_.deviceinfo.label -match 'scsi controller'} | where{$_.key -eq 1000}
    $econtrol = $item.config.hardware.device | where{$_.deviceinfo.label -match 'scsi controller'} | where{$_.key -ne 1000}
    $harddisks = $item.config.hardware.Device | where{$_.deviceinfo.label -match 'hard disk'} | where{$_.controllerkey -ne '1000'}
    $myvm = get-vm $item.name
    if($harddisks)
    {
         
        foreach($disk in $harddisks)
        {
            write-host "Changing $($item.name) $($disk.deviceinfo.label) to SAS controller" -f yellow
            $setdisk = $myvm | get-harddisk | where{$_.name -match "$($disk.deviceinfo.label)"} 
            $setdisk | Set-HardDisk -Controller ($myvm | get-scsicontroller | where{$_.key -eq '1000'}) -confirm:$false -Verbose
        }
    } 

    if($econtrol)
    {
        foreach($control in $econtrol)
        {
            if($control.deviceinfo.summary -notmatch 'paravirtual')
            {
                change-paravirtual -view $item -control $control
            }
        }
        
    }

    
    $item.poweronvm_task($null)
}

$checker = invoke-runspace -list $shutdown_list.name -scriptblock $script

try
{
    $err = Compare-Object $computers -DifferenceObject $checker | where{$_.sideindicator -eq '<='}
}catch{}

while($err)
{
    foreach($vm in $shutdown_list){$vm.updateviewdata()}
    write-host "=================================================`n" -f darkred
    $err.InputObject
    write-host "`n"
    write-host 'Waiting for vms to come back online' -f yellow

    sleep 10
    
    $checker = invoke-runspace -list $shutdown_list.name -scriptblock $script

    try
    {
        $err = Compare-Object $computers -DifferenceObject $checker | where{$_.sideindicator -eq '<='}
    }catch{}
}

###############################get driveinfo

$script =
{ 
    param($computername)

    $process = 
        
    invoke-command -computername $computername -ScriptBlock `
    {
        $sfvol = get-partition |where{$_.diskpath -match 'solid' -and $_.driveletter -match '[a-zA-Z]'}

        $labels = get-volume 
        $collection = @()
        foreach($vol in $sfvol)
        {
    
            $driveletter = $vol.driveletter
            $drivesize = [math]::ceiling(($vol | get-disk).size/1gb)

            $myobject = New-Object -TypeName psobject -Property @{
    
                DriveLetter = $driveletter
                DriveSize = $drivesize
                Label = ($labels | where{$_.driveletter -eq $driveletter}).filesystemlabel
                UniqueID = $vol.uniqueid
            } 

            $collection += $myobject 
        } 

        return $collection
    } | Sort-Object -Property driveletter -Descending
        
    return $process
}

$driveinfo = invoke-runspace -list $shutdown_list.name -scriptblock $script


####################################### function to create controllers
function create-control
{
    param($view)


    $view.UpdateViewData()

    $bus = (($view.config.hardware.device | where{$_.deviceinfo.label -match 'scsi controller'}).busnumber | measure -Maximum).maximum
    ##############################Adding iscsi controller
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.DeviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (1)
    $spec.DeviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $spec.DeviceChange[0].Device = New-Object VMware.Vim.ParaVirtualSCSIController
    $spec.DeviceChange[0].Device.SharedBus = 'noSharing'
    $spec.DeviceChange[0].Device.ScsiCtlrUnitNumber = 7
    $spec.DeviceChange[0].Device.DeviceInfo = New-Object VMware.Vim.Description
    $spec.DeviceChange[0].Device.DeviceInfo.Summary = 'New SCSI controller'
    $spec.DeviceChange[0].Device.DeviceInfo.Label = 'New SCSI controller'
    $spec.DeviceChange[0].Device.Key = -110
    $spec.DeviceChange[0].Device.BusNumber = $($bus + 1)
    $spec.DeviceChange[0].Operation = 'add'
    $spec.CpuFeatureMask = New-Object VMware.Vim.VirtualMachineCpuIdInfoSpec[] (0)
    $view.ReconfigVM_Task($spec) | out-null
            
    sleep 5

    $view.UpdateViewData()
    $newbus = (($view.config.hardware.device | where{$_.deviceinfo.label -match 'scsi controller'} | ?{$_.busnumber -eq $($bus +1)})).unitnumber
            
    while(!($newbus))
    {
        $view.UpdateViewData()
        $newbus = (($view.config.hardware.device | where{$_.deviceinfo.label -match 'scsi controller'} | ?{$_.busnumber -eq $($bus +1)})).unitnumber
            
    }

    return $newbus
}


############################################## Create vmdks on Vms and format
$operation = 0
foreach($comp in ($driveinfo.pscomputername | select -Unique))
{
    $operation ++ 
    write-host "_____________________" -f yellow
    write-host "∙$($comp)∙" -f green
    write-host "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯" -f yellow
    Write-Progress -Activity "Creating Drives for $comp" -Status 'Progress' -PercentComplete ($operation/($driveinfo.pscomputername | select -Unique).count*100)


    $drives = $driveinfo | where{$_.pscomputername -eq $comp} 

    if($drives.count -le 3)
    {
        $view = $shutdown_list | where{$_.name -eq $comp}
        $view.UpdateViewData()
        $myvm = get-vm $view.name
        if($view)
        {
            
            $eControl = $view.config.hardware.device | where{$_.deviceinfo.label -match 'scsi controller'} | where{$_.key -ne '1000'}

            write-host 'Creating New Drives and Formatting...' -f cyan
            
            

            $count = 0
            foreach($drive in $drives)
            {
                $newdrivel = $letters[$count]
                $dlabel = $drive.label

                if($econtrol[$count] 2>$Null)
                {

                    $mycontrol = $myvm |Get-ScsiController | where{$_.key -eq $($econtrol[$count].key)}
                    $newinfo = $myvm | New-HardDisk -capacitygb $drive.drivesize -controller $mycontrol
                    $drive | add-member -NotePropertyName ("vmdk" + $count) -NotePropertyValue $($newinfo.filename)

                }
                else
                {
                    $unit = (create-control -view $view)
                    $newcontroller = $myvm | get-scsicontroller | where{$_.unitnumber -eq $unit}
                    $newinfo = $myvm | New-HardDisk -capacitygb $drive.drivesize -controller ($myvm | Get-ScsiController | where{$_.unitnumber -eq $newcontroller.UnitNumber})
                    $drive | add-member -NotePropertyName ("vmdk" + $count) -NotePropertyValue $($newinfo.filename)
                }

                $drive | Add-Member -NotePropertyName NewLetter -NotePropertyValue $newdrivel

                ############################format drive and online offline disks

                invoke-command -computername $drive.pscomputername -ScriptBlock `
                {
                    param($newdrivel,$dlabel,$drive)

                    $drive | export-csv c:\windows\temp\driveimport.csv -append -NoTypeInformation
                    $diskchk = get-disk | where{$_.OperationalStatus -eq 'offline'} 
                    
                    if($diskchk)
                    {
                        foreach($d in $diskchk)
                        {
                            "select disk $($d.number)","attributes disk clear readonly","Online disk" | diskpart
                        }
                    }

                    $disk = (get-disk | ?{$_.partitionstyle -match 'raw'}).number
                    "rescan","sel disk $($disk)","online disk",'attributes disk clear readonly',"convert gpt","create partition primary","assign letter $($newdrivel)","format fs=ntfs label=$($dlabel) quick unit=64k"|diskpart
                    

                } -ArgumentList $newdrivel,$dlabel,$drive
                $count ++
            }
        }

    }
    else
    {
        write-error "$comp No Drives!"
        continue
    }
}

write-host "Drive Creations Complete." -f yellow
###########################push copy scripts 

write-host "All Drives Created, Pushing copy Scripts..." -f Cyan


foreach($comp in ($driveinfo.pscomputername | select -unique))
{
    write-host "_____________________" -f yellow
    write-host "∙$($comp)∙" -f green
    write-host "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯" -f yellow

    copy-item .\ecopy.ps1 \\$comp\c$\windows\temp\ -force -verbose
    copy-item .\tcopy.ps1 \\$comp\c$\windows\temp\ -force -verbose
    copy-item .\scopy.ps1 \\$comp\c$\windows\temp\ -force -verbose
    
    New-PSSession $comp -SessionOption (New-PSSessionOption -IdleTimeout 2147483647)

    $proc = 
    invoke-command -ScriptBlock `
    {
        
        Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy Bypass -Force | out-null
        REG ADD HKLM\SYSTEM\CurrentControlSet\services\pvscsi\Parameters\Device /v DriverParameter /t REG_SZ /d "RequestRingPages=32,MaxQueueDepth=254" /f
        $driveinfo = import-csv c:\windows\temp\driveimport.csv
        foreach($drive in $driveinfo)
        {
            $newid = (get-volume | where{$_.driveletter -eq $drive.newletter} | get-partition).uniqueid
            $drive | add-member -NotePropertyName NewId -NotePropertyValue $newid       
        }
        $driveinfo | export-csv c:\windows\temp\driveimport.csv -NoTypeInformation -Force
        
        ##### stop services
        if(get-service mssqlserver,sqlserveragent 2>$null)
        {
            get-service mssqlserver,sqlserveragent | set-service -StartupType manual
            get-service mssqlserver,sqlserveragent | stop-service -force
        }
        
        sleep 1
        
        $powershellPath = "$env:windir\system32\windowspowershell\v1.0\powershell.exe"
        $process = Start-Process $powershellPath -NoNewWindow -ArgumentList ("c:\windows\temp\ecopy.ps1 -ExecutionPolicy Bypass -noninteractive") -PassThru
        $process1 = Start-Process $powershellPath -NoNewWindow -ArgumentList ("c:\windows\temp\tcopy.ps1 -ExecutionPolicy Bypass -noninteractive") -PassThru
        $process2 = Start-Process $powershellPath -NoNewWindow -ArgumentList ("c:\windows\temp\scopy.ps1 -ExecutionPolicy Bypass -noninteractive") -PassThru
        write-output $process
        write-output $process1
        write-output $process2

    } -Session (get-pssession | where{$_.computername -eq $comp})
    

    write-output $Proc |ft
    $newidinfo = import-csv "\\$comp\c$\windows\temp\driveimport.csv"
    foreach($drive in ($driveinfo | where{$_.pscomputername -eq $($comp)}))
    {
        $drive | add-member -NotePropertyName NewId -NotePropertyValue ($newidinfo | where{$_.newletter -eq $drive.newletter}).newid
        
        for($i = 0; $i -lt $proc.count; $i++)
        {
            $drive | Add-Member -NotePropertyName "process$($i)" -NotePropertyValue ($proc[$i].id)
        }
    }
    $driveinfo | select pscomputername,driveletter,label,drivesize,uniqueid,newletter,process0,process1,process2,newid | export-csv ".\driveinfo-$($mydate.replace('/','-').replace(' ','-').replace(':','-')).csv" -append -NoTypeInformation

} 

write-host "Done Pushing Copy Scripts" -f Cyan
write-host "`n===================================================================================================" -f yellow
Write-Warning "DO NOT CLOSE ISE WHILE DATA COPIES ARE GOING, CLOSE ONLY WHEN COPYING DATA IS COMPLETE!!!"
write-host  "===================================================================================================`n" -f yellow
write-host "Check Data copy status using Log.ps1 to Grab Logs" -f yellow 
