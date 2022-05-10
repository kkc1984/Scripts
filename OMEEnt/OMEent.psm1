
Get-ChildItem -Path $PSScriptRoot\*.ps1 | `
 ForEach-Object { . $_.fullname; Export-ModuleMember -Function ([IO.PATH]::GetFileNameWithoutExtension($_.fullname)) }