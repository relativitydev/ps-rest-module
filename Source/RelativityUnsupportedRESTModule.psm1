<#
This Powershell module lists unsupported REST calls.  These are subject to change in future versions
of Relativity and not supported in the same way as REST calls listed in the kCura public documenation.
For cutting edge applications, these may allow you to accomplish work beyond what's possible with the
documented API coverage. If your application requires high dependability and future compatibility,
DO NOT use any of these REST calls.
#>

# Worker Status functions
#######################
<#
    Returns a list of all worker servers

    "Get worker status for all workers" - Relativity.Services.Interfaces.Private.xml
#>
function Read-AllWorkerServers {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection
)
    $Connection.RestAction = '/api/Relativity.Services.WorkerStatus.IWorkerStatusModule/WorkerStatus/GetAllWorkersAsync'
    $results = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Post -Headers $Connection.RestHeaders

    return (New-PipedObject -Connection $Connection -Results $results)
}