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

# Workspace functions
<#
    Returns all workspaces in the Relativity instance
#>
function Get-AllWorkspaces {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection
)

    $Connection.RestAction = '/Relativity/Workspace'
    $results = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Get -Headers $Connection.RestHeaders
    return (New-PipedObject -Connection $Connection -Results $results)
}
<#
    Returns one or more workspaces from an array of workspace IDs

    $ArtifactIDs - the artifact IDs of the workspace(s) you want to retrieve
#>
function Get-Workspace {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$true)]
    [System.Int32[]]$ArtifactIDs
)

    $results = @{}
    For ($i = 0; $i -lt $ArtifactIDs.Count; $i++) {

        $Connection.RestAction = ('/Relativity/Workspace/{0}' -f $ArtifactIDs[$i])
        $result = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Get -Headers $Connection.RestHeaders
        $results.Add($ArtifactIDs[$i], $result)
    }
    return (New-PipedObject -Connection $Connection -Results $results)
}
<#
    Returns one or more workspaces based on whether the name matches 

    $Name - This is automatically fuzzy; no need for %
#>
function Query-WorkspaceByName {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$true)]
    [System.String]$Name
)

    $Connection.RestAction = '/Relativity/Workspace/QueryResult'
    $query = Get-Condition -Field 'Name' -Value $Name -Condition 'LIKE'
    $results = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Post -Headers $Connection.RestHeaders -Body $query -ContentType 'application/json'
    return (New-PipedObject -Connection $Connection -Results $results)
}

# User functions
<#
    Returns all users in the Relativity instance
#>
function Get-AllUsers {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection
)
    $Connection.RestAction = '/Relativity/User'
    $results = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Get -Headers $Connection.RestHeaders
    return (New-PipedObject -Connection $Connection -Results $results)
}
<#
    Returns one or more users from an array of user IDs

    $ArtifactIDs - the artifact IDs of the user(s) you want to retrieve
#>
function Get-User {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$true)]
    [System.Int32[]]$ArtifactIDs
)
    $results = @{}
    For ($i = 0; $i -lt $ArtifactIDs.Count; $i++) {

        $Connection.RestAction = ('/Relativity/User/{0}' -f $ArtifactIDs[$i])
        $result = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Get -Headers $Connection.RestHeaders
        $results.Add($ArtifactIDs[$i], $result)
    }
    return (New-PipedObject -Connection $Connection -Results $results)
}
<#
    Returns one or more users based on whether the name matches 

    $Name - This is automatically fuzzy; no need for %
#>
function Query-UserByLastName {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$true)]
    [System.String]$Name
)

    $Connection.RestAction = '/Relativity/User/QueryResult'
    $query = Get-Condition -Field 'Last Name' -Value $Name -Condition 'LIKE'
    $results = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Post -Headers $Connection.RestHeaders -Body $query -ContentType 'application/json'

    return (New-PipedObject -Connection $Connection -Results $results)
}

# Application functions
<#
    Returns all applications in a specified workspace

    $WorkspaceIDs - specify which workspace (-1 [EDDS] doesn't work at this time)
#>
function Get-AllApplications {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$true)]
    [System.Int32[]]$WorkspaceIDs
)

    $results = @{}
    For ($i = 0; $i -lt $WorkspaceIDs.Count; $i++) {

        $Connection.RestAction = ('/Workspace/{0}/Relativity Application' -f $WorkspaceIDs[$i])
        $result = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Get -Headers $Connection.RestHeaders
        $results.Add($WorkspaceIDs[$i], $result)
    }
    return (New-PipedObject -Connection $Connection -Results $results)
}
<#
    Returns one or more applications by guid from the specified workspace

    $WorkspaceID - the workspace the application(s) reside
    $Guids - One or more application guids
#>
function Get-Application {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$true)]
    [System.Int32]$WorkspaceID,

    [parameter(Mandatory=$true)]
    [System.Guid[]]$Guids
)

    $results = @{}
    For ($i = 0; $i -lt $Guids.Count; $i++) {

        $Connection.RestAction = ('/Workspace/{0}/Relativity Application/{1}' -f $WorkspaceID, $Guids[$i])
        $result = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Get -Headers $Connection.RestHeaders
        $results.Add($Guids[$i], $result)
    }
    return (New-PipedObject -Connection $Connection -Results $results)
}

# Object Type functions
<#
    Returns all object types from one or more workspaces

    $WorkspaceIDs - an array of workspace id(s) to retrieve all object types from
#>
function Get-AllObjectTypes {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$true)]
    [System.Int32[]]$WorkspaceIDs
)

    $results = @{}
    For ($i = 0; $i -lt $WorkspaceIDs.Count; $i++) {

        $Connection.RestAction = ('/Workspace/{0}/Object Type' -f $WorkspaceIDs[$i])
        $result = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Get -Headers $Connection.RestHeaders
        $results.Add($WorkspaceIDs[$i], $result)
    }
    return (New-PipedObject -Connection $Connection -Results $results)
}

# Object Query functions
<#
    Queries one or more of any object type in Relativity in a certain workspace

    $ArtifactTypeIDs - an array of object type ids.  These may be retrieved from a workspace using the 
                       Get-AllObjectTypes cmdlet and is called the 'Descriptor Artifact Type ID' field
    $WorkspaceID - the workspace to query.

    Note: will return ALL fields on the object.  i.e. 'Fields': ['*']
#>
function Query-ObjectByType {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$true)]
    [System.Int32[]]$ArtifactTypeIDs,

    [parameter(Mandatory=$true)]
    [System.Int32]$WorkspaceID
)

    # This is a basic template of an object query request
    $BaseBody = "{
        'workspaceId': {WORKSPACEID},
        'artifactTypeId': {ARTIFACTTYPEID},
        'query': {
            'Fields': ['*'],
            'Condition': ""('Artifact ID' > 1)"",
            'Sorts': ['Artifact ID DESC']
            },
        'start': 1,
        'length': 100,
        'includePermissions': [2,3,4],
        'queryToken': ''
    }"

    $Connection.RestAction = '/api/Relativity.Services.ObjectQuery.IObjectQueryModule/Object%20Query%20Manager/QueryAsync'
    $results = @{}
    For ($i = 0; $i -lt $ArtifactTypeIDs.Count; $i++) {

        $body = $BaseBody.Replace('{ARTIFACTTYPEID}', $ArtifactTypeIDs[$i]).Replace('{WORKSPACEID}', $WorkspaceID)
        $result = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Post -Headers $Connection.RestHeaders -Body $body -ContentType 'application/json'
        $results.Add($ArtifactTypeIDs[$i], $result)
    }
    return (New-PipedObject -Connection $Connection -Results $results)
}

# Document functions
<#
    Reads all fields from one or more documents in a certain workspace

    $ArtifactIDs - The artifact ID(s) of the document(s) to be read.
    $WorkspaceID - the workspace to read from.

    Note: will return ALL fields on the object.  i.e. 'Fields': ['*']
#>
function Read-Document {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$true)]
    [System.Int32[]]$ArtifactIDs,

    [parameter(Mandatory=$true)]
    [System.Int32]$WorkspaceID
)

    $Connection.RestAction = '/Relativity.REST/Workspace/{WORKSPACEID}/Document/{ARTIFACTID}'
    $results = @{}
    For ($i = 0; $i -lt $ArtifactIDs.Count; $i++) {

        $Connection.RestAction = ('/Workspace/{0}/Document/{1}' -f $WorkspaceID, $ArtifactIDs[$i])
        $result = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Get -Headers $Connection.RestHeaders
        $results.Add($ArtifactIDs[$i], $result)
    }
    return (New-PipedObject -Connection $Connection -Results $results)
}

# Saved Search (Keyword) functions
<#
    Reads all fields from a saved search in a certain workspace

    $ArtifactIDs - The artifact ID(s) of the saved searches(s) to be read.
    $WorkspaceID - the workspace to read from.

    Note: will return ALL fields on the object.  i.e. 'Fields': ['*']
#>
function Read-SavedSearch {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$true)]
    [System.Int32[]]$ArtifactIDs,

    [parameter(Mandatory=$true)]
    [System.Int32]$WorkspaceID
)
    # This is a basic template of a saved search read request
    $BaseBody = "{
        'workspaceArtifactID': {WORKSPACEID},
        'searchArtifactID': {SAVEDSEARCHID}
    }"

    $Connection.RestAction = '/api/Relativity.Services.Search.ISearchModule/Keyword%20Search%20Manager/ReadSingleAsync'
    $results = @{}
    For ($i = 0; $i -lt $ArtifactIDs.Count; $i++) {

        $body = $BaseBody.Replace('{SAVEDSEARCHID}', $ArtifactIDs[$i]).Replace('{WORKSPACEID}', $WorkspaceID)
        $result = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Post -Headers $Connection.RestHeaders -Body $body -ContentType 'application/json'
        $results.Add($ArtifactIDs[$i], $result)
    }
    return (New-PipedObject -Connection $Connection -Results $results)
}

<#
    Reads all fields which may be used as criteria for a saved search in a certain workspace

    $WorkspaceID - the workspace to read from.
#>
function Read-AvailableFieldsForSearchCriteria {
[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [PSCustomObject]$Connection,

    [parameter(Mandatory=$true)]
    [System.Int32]$WorkspaceID
)
    # This is a basic template of a GetFieldsForCriteriaCondition request
    $BaseBody = "{
        'workspaceArtifactID': {WORKSPACEID},
        'artifactTypeID': 10
    }"

    $Connection.RestAction = '/api/Relativity.Services.Search.ISearchModule/Keyword%20Search%20Manager/GetFieldsForCriteriaConditionAsync'
    $results = @{}

    $body = $BaseBody.Replace('{WORKSPACEID}', $WorkspaceID)
    $results = Invoke-RestMethod -Uri $Connection.GetRestUri() -Method Post -Headers $Connection.RestHeaders -Body $body -ContentType 'application/json'

    return (New-PipedObject -Connection $Connection -Results $results)
}