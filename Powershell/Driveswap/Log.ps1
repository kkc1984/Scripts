$computers = import-csv .\driveinfo*.csv 

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
        $comp
    )
    
    write-host "Checking for Log for $comp..." -f cyan
    if(test-path "\\$comp\c$\windows\temp\E_xsfer.txt")
    {
        $e = get-content "\\$comp\c$\windows\temp\E_xsfer.txt" -tail 20
        if($e)
        {
            $e[0] = "/\/\/\/========/\/\/\/\========E COPY SCRIPT========/\/\/\/\========/\/\/\/\`n"
        }
    }
    if(test-path "\\$comp\c$\windows\temp\T_xsfer.txt")
    {
        $t = get-content "\\$comp\c$\windows\temp\T_xsfer.txt" -tail 20
        if($t)
        {
            $t[0] = "/\/\/\/\========/\/\/\/\========T COPY SCRIPT========/\/\/\/\========/\/\/\/\`n"
        }
    }
    if(test-path "\\$comp\c$\windows\temp\S_xsfer.txt")
    {
        $s = get-content "\\$comp\c$\windows\temp\S_xsfer.txt" -tail 20
        if($s)
        {
            $s[0] = "/\/\/\/\========/\/\/\/\========S COPY SCRIPT========/\/\/\/\========/\/\/\/\`n"
        }
    }
    
    $all = $e + $t + $s
    $output = @()
    foreach($line in $all.trimend())
    {
        $output += $comp + "`t" + $line 
    }
    return $output

}

$checker = invoke-runspace -list ($computers.pscomputername | select -unique) -scriptblock $script

foreach($comp in ($computers.pscomputername | select -unique))
{
    $log = $checker | select-string -pattern "$comp"
    if($log)
    {
        $log | set-content .\logs\$comp.txt -Force
        $logcount = ($log | select-string "Ended : .*,.*, \d{4} \d{1,2}:\d{2}:\d{2} .{2}").count

        if($logcount -lt 3)
        {
            Write-host "$comp - $logcount Drives has Finished." -f yellow
        }
        else
        {    
            Write-host "$comp - $logcount Drives has Finished. COMPLETE." -f yellow
        }
        
    }
    else
    {
        write-error "Couldn't Find Logs for $comp" 
    }
    write-host "`n===========================================" -f cyan
    write-host "Log Files In .\Logs Folder" -f green
    write-host "===========================================`n" -f cyan
}


