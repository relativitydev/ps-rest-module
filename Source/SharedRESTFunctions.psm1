# Setup functions
<#
    Takes a PSCredential and returns a Dictionary of the required headers for any REST action

    $Credential - use the cmdlet Get-Credential to retrieve

    Required Headings:
    Basic Authorization as a base64-encoded string from the username and password
    X-CSRF-Header as an empty string
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
    Takes the REST host and action and returns a Uri object.  Optionally you may set the protocol.

    $RestHost   - relativity-9-4
    $RestAction - /Workspace/1224567
    $Protocol   - http or https
#>
function Get-RestUri { 
param(
    [parameter(Mandatory=$true)]
    $RestHost,

    [parameter(Mandatory=$true)]
    $RestAction,

    [parameter(Mandatory=$true)]
    $Protocol
)

    # Standardize the action path syntax
    if ($RestAction[0] -ne '/') {
        Throw [System.ArgumentException] "Please add a '/' before your action "
    }

    $uri_string = [System.String]::Concat($Protocol, '://', $RestHost, '/Relativity.Rest', $RestAction)
    return New-Object -TypeName System.Uri($uri_string)
}
<#
    Returns a connection object which contains all the necessary
    information to invoke a REST call.

    $RestHost   - relativity-9-4
    $RestAction - /Workspace/1224567 (default is '/')
    $Protocol   - http (default) or https
    $Credential - use the cmdlet Get-Credential to retrieve
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
    [System.String]$RestProtocol = 'http',

    [parameter(Mandatory=$false)]
    [switch]$DefaultUser
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
    Returns an object that encapsulates both the connection and the
    results from a REST call.  This encapsulation can, so long as the
    method supports it, make cmd line chaining possible.
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
<#
    Returns an array of the currently supported condition types
    for the Get-Condition cmdlet
#>
function Get-ConditionTypes {

    return @('LIKE')
}
<#
    Returns a string for a standard REST query condition

    $Field - ControlNumber
    $Value - AZIPPER% (will return all documents with this prefix)
    $Condition - LIKE

    Note: Returns all fields on the object i.e. 'fields': ['*']
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
        Throw [System.ArgumentException] "Your condition does match one of the supported condition types.  Please check the results of Get-ConditionTypes."
    }

    $result = "{ 'condition': "" '{FIELD}' {CONDITION} '{VALUE}' "", 'fields': ['*'] }".
                Replace('{FIELD}', $Field).
                Replace('{VALUE}', $Value).
                Replace('{CONDITION}', $Condition)

    return $result
}
<#
    Removes all specified properties from the object
    and returns it

    $Object     - any PSObject type
    $Properties - TBD
#>
function Remove-Properties {
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
    Replaces the specified properties on the object and
    returns it

    $Object     - Any PSObject type
    $Properties - 
#>
function Replace-Properties {
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
    Returns a plain-text variant of the secure string from Get-Credential.
#>
function Get-PlainText {
# Function borrowed from http://blog.majcica.com/2015/11/17/powershell-tips-and-tricks-decoding-securestring/
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
    Replaces the space in a string with %20
#>
function Encode-Spaces {
param(
    [parameter(Mandatory=$true)]
    [System.String]$Name
)
    return ($Name -replace ' ', '%20')
}