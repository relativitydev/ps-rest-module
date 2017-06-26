<#
This Powershell module adds functions common to both the RelativityRESTModule
and the RelativityUnsupportedRESTModule. These simplify interactions with
REST endpoints and encourage templates and piping. If you choose to add functions
to this repository, I strongly encourage you to build with these functions.
#>
# Setup functions
#######################
<#
.SYNOPSIS
Gets the required headers for any REST action.

.PARAMETER Credential
The username and password credentials used to connect to the REST endpoint.

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
C:\PS> New-ConnectionObject -Credential (Get-Credential)

.NOTES
You may use the Get-Credential cmdlet to retrieve the credential object in a secure fashion.

Relativity REST endpoints require two headers:

    A basic authorization as a base64-encoded string of the username and password
    An empty X-CSRF-Header
#>
function Get-RestHeaders {
param(
    [parameter(Mandatory=$true)]
    [pscredential]$Credential
)

    $key = [System.String]::Format("{0}:{1}", $Credential.UserName, (Get-PlainText $Credential.Password))
    $base64key = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($key))
    return @{Authorization=("Basic {0}" -f $base64key); "X-CSRF-Header"=" "}
}
<#
.SYNOPSIS
Converts the REST protocol, host, and action into a URI.

.PARAMETER Protocol
The connection protocol (http/https).

.PARAMETER RestHost
The hostname of the Relativity instance you wish to connect with.

.PARAMETER RestAction
The REST endpoint that will be acted on.  Please include a '/' at the beginning. '/Relativity.REST' is already included.

.OUTPUTS
System.Uri

.EXAMPLE
C:\PS> Get-RestUri -Protocol 'http' -RestHost 'my-rel-instance' -RestAction '/Workspace/1234567'
#>
function Get-RestUri { 
param(
    [parameter(Mandatory=$true)]
    $Protocol,

    [parameter(Mandatory=$true)]
    $RestHost,

    [parameter(Mandatory=$false)]
    $RestAction
)

    # Standardize the action path syntax
    if ($RestAction[0] -ne '/') {
        Throw [System.ArgumentException] "Please add a '/' before your action"
    }
    # Notify user that Relativity.REST is already included
    if ($RestAction.ToLower().Contains('relativity.rest')) {
        Throw [System.ArgumentException] "Relativity.REST is already included in the URI, please remove"
    }

    $uri_string = [System.String]::Concat($Protocol, '://', $RestHost, '/Relativity.REST', $RestAction)
    return New-Object -TypeName System.Uri($uri_string)
}
<#
.SYNOPSIS
Creates a custom object that encapsulates functionality necessary to connect to a REST endpoint.

.PARAMETER Credential
The username and password credentials used to connect to the REST endpoint.

.PARAMETER RestHost
The hostname of the Relativity instance you wish to connect with.

.PARAMETER RestAction
The REST endpoint that will be acted on.  Please include a '/' at the beginning. '/Relativity.REST' is already included. '/' is the default.

.PARAMETER Protocol
The connection protocol (http/https). 'http' is the default.

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
C:\PS> New-ConnectionObject -Credential (Get-Credential) -RestHost 'my-rel-instance'
#>
function New-ConnectionObject {
param(
    [parameter(Mandatory=$true)]
    [pscredential]$Credential,

    [parameter(Mandatory=$true)]
    [System.String]$RestHost,

    [parameter(Mandatory=$false)]
    [System.String]$RestAction = '/',

    [parameter(Mandatory=$false)]
    [System.String]$RestProtocol = 'http'
)
    $con = New-Object -TypeName PSCustomObject

    Add-Member -InputObject $con -MemberType NoteProperty -Name RestHost -Value $RestHost
    Add-Member -InputObject $con -MemberType NoteProperty -Name RestAction -Value $RestAction
    Add-Member -InputObject $con -MemberType NoteProperty -Name RestHeaders -Value (Get-RestHeaders -Credential $Credential)
    Add-Member -InputObject $con -MemberType NoteProperty -Name RestProtocol -Value $RestProtocol
    Add-Member -InputObject $con -MemberType ScriptMethod -Name GetRestUri -Value {Get-RestUri -RestAction $this.RestAction -RestHost $this.RestHost -Protocol $this.RestProtocol}

    return $con
}
<#
.SYNOPSIS
Returns an object that encapsulates both the connection and the results from a REST call.  Can be chained into functions with pipe support.

.PARAMETER Connection
A custom object with functionality necessary to connect to a REST endpoint.  Use the New-ConnectionObject cmdlet.

.PARAMETER Results
A custom object with the results of the REST call.

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
C:\PS> New-PipedObject -Connection $con -Results $result
#>
function New-PipedObject {
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$false)]
    [PSCustomObject]$Results
)
    $obj = New-Object PSCustomObject

    Add-Member -InputObject $obj -MemberType NoteProperty -Name Connection -Value $Connection
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Results -Value $Results

    return $obj
}

# Helper functions
#######################
<#
.SYNOPSIS
A list of condition types currently supported by this module.

.OUTPUTS
System.Array

.EXAMPLE
C:\PS> Get-ConditionTypes
#>
function Get-ConditionTypes {

    return @('LIKE')
}
<#
.SYNOPSIS
Returns a standard REST query condition string.

.PARAMETER Field
Name of the conditional field.

.PARAMETER Value
The value compared for the field.

.PARAMETER Condition
The condition the value must meet.  Use Get-ConditionTypes to list which conditions are supported by this module.

.OUTPUTS
System.String. Returns all fields on the object i.e. 'fields': ['*']

.EXAMPLE
C:\PS> Get-Condition -Field 'ControlNumber' -Value 'AZIPPER%' -Condition 'LIKE'
#>
function Get-Condition {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [System.String]$Field,

    [parameter(Mandatory=$true)]
    [System.String]$Value,

    [parameter(Mandatory=$true)]
    [System.String]$Condition
)

    # Ensures only supported conditions are used
    if ((Get-ConditionTypes).Contains($Condition) -eq $false)
    {
        Throw [System.ArgumentException] "Your condition does match one of the supported condition types.  Please compare with the Get-ConditionTypes output."
    }

    $result = "{ 'condition': "" '{FIELD}' {CONDITION} '{VALUE}' "", 'fields': ['*'] }".
                Replace('{FIELD}', $Field).
                Replace('{VALUE}', $Value).
                Replace('{CONDITION}', $Condition)

    return $result
}
<#
.SYNOPSIS
Removes all specified properties from the object.

.PARAMETER Object
The object to remove properties from.

.PARAMETER Properties
A list of the names of properties to remove.

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
C:\PS> Remove-ObjectProperties -Object $obj -Properties @('ArtifactTypeID', 'System Created On')

.NOTES
This function's intent is to simplify the creation of some Relativity objects by removing system fields from
a successful read, replacing necessary fields, and sending the object back into a write.
#>
function Remove-ObjectProperties {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [System.Management.Automation.PSObject]$Object,

    [parameter(Mandatory=$true)]
    [System.Array]$Properties
)

    Foreach ($property in $Properties) {
        $Object.PSObject.Properties.Remove($property)
    }

    return $Object
}
<#
.SYNOPSIS
Replaces all specified properties on the object.

.PARAMETER Object
The object to replace properties on.

.PARAMETER Properties
A hashtable of the names of properties to replace and their new values.

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
C:\PS> Replace-ObjectProperties -Object $obj -Properties {'FirstName':'Bob','LastName':'Smith'}

.NOTES
This function's intent is to simplify the creation of some Relativity objects by removing system fields from
a successful read, replacing necessary fields, and sending the object back into a write.
#>
function Replace-ObjectProperties {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [System.Management.Automation.PSObject]$Object,

    [parameter(Mandatory=$true)]
    [System.Collections.Hashtable]$Properties
)

    Foreach ($property in $Properties.Keys) {

        $Object.$property = $Properties.Item($property)
    }

    return $Object
}
<#
.SYNOPSIS
Returns a plain-text variant of the secure string from Get-Credential.

.PARAMETER SecureString
A secure password string.

.OUTPUTS
System.String

.EXAMPLE
C:\PS> Get-PlainText (Get-Credential).Password

.NOTES
Function borrowed from http://blog.majcica.com/2015/11/17/powershell-tips-and-tricks-decoding-securestring/
#>
function Get-PlainText {
[CmdletBinding()]
param
(
	[parameter(Mandatory = $true)]
	[System.Security.SecureString]$SecureString
)
	BEGIN { }
	PROCESS
	{
		$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString);
 
		try
		{
			return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr);
		}
		finally
		{
			[Runtime.InteropServices.Marshal]::FreeBSTR($bstr);
		}
	}
	END { }
}
<#
.SYNOPSIS
Replaces the space in a string with %20.

.PARAMETER Name
A string with spaces.

.OUTPUTS
System.String

.EXAMPLE
C:\PS> Encode-Spaces '/Object Manager'
'Object%20Manager'
#>
function Encode-Spaces {
param(
    [parameter(Mandatory=$true)]
    [System.String]$Name
)
    return ($Name -replace ' ', '%20')
}