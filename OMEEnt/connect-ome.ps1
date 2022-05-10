
function connect-ome
{
    [cmdletbinding()]
    param
    (
        [parameter(mandatory)]$server,
        [parameter(mandatory)][pscredential]$credential
    )
    
    try
    { 
        add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@ 
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    catch
    {

    }

    
    Invoke-RestMethod -Uri "https://$($server)/api" -Method Get -ContentType 'application/json' -credential $credential -SessionVariable mysess
    
    $global:mysess = $mysess
    $global:server = $server
}