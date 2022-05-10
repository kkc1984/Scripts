function get-omealerts 
{
    param
    (
        $global:credential,
        [switch]$importtosql
    )

    if($importtosql -eq $true)
    {
        $atlalerts =  import-csv 'd:\Compliancy\atl\atlhardwarealerts.csv' | where{$_.severityname -eq 'critical' -and $_.subcategory -match 'memory|pci device|physical disk|power supply|processory|redundancy|virtual disk'}
        $plasalerts = import-csv 'd:\Compliancy\LASSAAS\plashardwarealerts.csv' | where{$_.severityname -eq 'critical' -and $_.subcategory -match 'memory|pci device|physical disk|power supply|processory|redundancy|virtual disk'}
        $toralerts = import-csv 'd:\Compliancy\tor\torhardwarealerts.csv'| where{$_.severityname -eq 'critical' -and $_.subcategory -match 'memory|pci device|physical disk|power supply|processory|redundancy|virtual disk'}
        $dlasalerts = import-csv 'd:\Compliancy\devLV\dlashardwarealerts.csv'| where{$_.severityname -eq 'critical' -and $_.subcategory -match 'memory|pci device|physical disk|power supply|processory|redundancy|virtual disk'}
        $devalerts = import-csv 'D:\Compliancy\dev\qtsmiahardwarealerts.csv'| where{$_.severityname -eq 'critical' -and $_.subcategory -match 'memory|pci device|physical disk|power supply|processory|redundancy|virtual disk'}
        $atlalerts1 =  import-csv 'd:\Compliancy\atl\atlhardwarealerts.csv' 
        $plasalerts1 = import-csv 'd:\Compliancy\LASSAAS\plashardwarealerts.csv'
        $toralerts1 = import-csv 'd:\Compliancy\tor\torhardwarealerts.csv'
        $dlasalerts1 = import-csv 'd:\Compliancy\devLV\dlashardwarealerts.csv'
        $devalerts1 = import-csv 'D:\Compliancy\dev\qtsmiahardwarealerts.csv'

        function importtosql
        {
            param($alerts,$alerts1,$mydc)
                

                $get_alert_query = @"
                    select * From HardwareAlerts Where datacenter = '$mydc' 
"@
                if($credential -ne $null)
                {
                    $sqlalerts = Invoke-Sqlcmd -ServerInstance '10.71.68.18' -Database 'CIEReporting' -Query $get_alert_query -Credential $credential
                    $sqlalerts1 = Invoke-Sqlcmd -ServerInstance '10.71.77.127' -Database 'Utility' -Query $get_alert_query -Credential $credential
                }
                else
                {
                    $sqlalerts = Invoke-Sqlcmd -ServerInstance '10.71.68.18' -Database 'CIEReporting' -Query $get_alert_query
                    $sqlalerts1 = Invoke-Sqlcmd -ServerInstance '10.71.77.127' -Database 'Utility' -Query $get_alert_query
                }
                ######################
                if ($sqlalerts -ne $Null)
                {
                    $newalerts = (compare-object -ReferenceObject ($sqlalerts | where{$_.datacenter -match "$mydc"}).id -DifferenceObject `
                    ($alerts).id | where{$_.sideindicator -eq '=>'}).inputobject
                }
                else
                {
                    $newalerts = $alerts.id
                }
                ######################
                if ($sqlalerts1 -ne $Null)
                {
                    $newalerts1 = (compare-object -ReferenceObject ($sqlalerts1 | where{$_.datacenter -match "$mydc"}).id -DifferenceObject `
                    ($alerts1).id | where{$_.sideindicator -eq '=>'}).inputobject
                }
                else
                {
                    $newalerts1 = $alerts1.id
                }
    
    
                $count = 1
                foreach($id in $newalerts)
                {
                
                    $object = ($alerts | where{$_.id -match "^$id$"})
        
                    $insert_query = @"
                        Insert into HardwareAlerts (ID,DataCenter,SeverityName,ServiceTag,DeviceName,IpAddress,TimeStamp,Message,RecommendedAction,Warranty,LastStatusTime,SubCategory) 
                        values ('$($object.id)','$($mydc)','$($object.SeverityName)','$($object.ServiceTag)','$($object.DeviceName)','$($object.IpAddress)','$($object.TimeStamp)','$($object.Message)','$($object.recommendedAction.replace("`'",""))','$($object.warranty)','$($object.LastStatusTime)','$($object.SubCategory)')
"@
                    write-host "$($object.servicetag) $count out of $($newalerts.count) from dc $mydc" -f yellow

                    if($credential -ne $Null)
                    {
                        Invoke-Sqlcmd -ServerInstance '10.71.68.18' -Database 'CIEReporting' -Query $insert_query -Credential $credential
                    }
                    else
                    {
                        Invoke-Sqlcmd -ServerInstance '10.71.68.18' -Database 'CIEReporting' -Query $insert_query
                    }
                    $count ++
        
                }

                #####################
                foreach($id in $newalerts1)
                {
                
                    $object = ($alerts1 | where{$_.id -match "^$id$"})
        
                    $insert_query = @"
                        Insert into HardwareAlerts (ID,DataCenter,SeverityName,ServiceTag,DeviceName,IpAddress,TimeStamp,Message,RecommendedAction,Warranty,LastStatusTime,SubCategory) 
                        values ('$($object.id)','$($mydc)','$($object.SeverityName)','$($object.ServiceTag)','$($object.DeviceName)','$($object.IpAddress)','$($object.TimeStamp)','$($object.Message)','$($object.recommendedAction.replace("`'",""))','$($object.warranty)','$($object.LastStatusTime)','$($object.SubCategory)')
"@
                    write-host "$($object.servicetag) $count out of $($newalerts1.count) from dc $mydc" -f yellow

                    if($credential -ne $Null)
                    {
                        Invoke-Sqlcmd -ServerInstance '10.71.77.127' -Database 'Utility' -Query $insert_query -Credential $credential
                    }
                    else
                    {
                        Invoke-Sqlcmd -ServerInstance '10.71.77.127' -Database 'Utility' -Query $insert_query
                    }
                    $count ++
        
                }
        }

        importtosql -alerts $dlasalerts -alerts1 $dlasalerts1 -mydc 'dlas'
        importtosql -alerts $atlalerts -alerts1 $atlalerts1 -mydc 'atl'
        importtosql -alerts $toralerts -alerts1 $toralerts1 -mydc 'tor'
        importtosql -alerts $plasalerts -alerts1 $plasalerts1 -mydc 'plas'
        importtosql -alerts $devalerts -alerts1 $devalerts1 -mydc 'qtsmiami'

    }
    else
    {
        $alluri = "https://$($server)/api/AlertService/Alerts?" + '$top=200000'

        $warrantyuri = "https://$($server)/api/WarrantyService/Warranties?" + '$top=5000'

        $devicesuri = "https://$($server)/api/DeviceService/Devices?" + '$top=5000'

        $allalerts = invoke-restmethod -uri $alluri -ContentType 'application/json' -method Get -websession $mysess
        $allwarranty = invoke-restmethod -uri $warrantyuri -ContentType 'application/json' -method Get -websession $mysess
        $alldevices = invoke-restmethod -uri $devicesuri -ContentType 'application/json' -method Get -websession $mysess
        
        
        $alertcollection = @()
    
        switch -regex ($server)
        {
            'd99sdomap01|10\.71\.69\.34'
            {
                $dc = 'qtsmiami'
            }
            'dw99ddomap01|10\.146\.16\.14'
            {
                $dc = 'dlas'
            }
            't0mdomap01|10\.130\.112\.90'
            {
                $dc = 'tor'
            }
            'e0mdomap01|10\.99\.112\.173'
            {
                $dc = 'atl'
            }
            'n0idomap01|10\.147\.16\.60'
            {
                $dc = 'plas'
            }
        }

        $allalerts.value | % `
        {
            $myalert = $_
            $myalert_tag = $myalert.AlertDeviceIdentifier
            $dayswar = ($allwarranty.value | where{$_.deviceidentifier -match "$myalert_tag"} | select -first 1).daysremaining
            $activewar =  if ($dayswar -gt 0)
                            {
                               'Yes'
                            }
                            elseif($dayswar -eq $null)
                            {
                                'Not Found'
                            }
                            else
                            {
                                'No'
                            }
            $lastinv = ($alldevices.value | where{$_.identifier-match "$myalert_tag"}).laststatustime.split(' ')[0]

            $Myobject = New-Object psobject  -Property @{
                ID = $myalert.Id
                DataCenter = $dc
                SeverityName = $myalert.SeverityName
                ServiceTag = $myalert.AlertDeviceIdentifier
                DeviceName = $myalert.AlertDeviceName
                IpAddress = $myalert.AlertDeviceIpAddress
                TimeStamp = $myalert.TimeStamp
                Message = $myalert.Message
                RecommendedAction = $myalert.RecommendedAction
                Warranty = $activewar
                LastStatusTime = $lastinv
                Subcategory = $myalert.SubCategoryName


            
            }
            $alertcollection += $myobject
        }
    
        return $alertcollection
    }
    
    
}