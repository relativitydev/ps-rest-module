# ps-rest-module
Open Source Community: A PowerShell module to facilitate the integration of Relativity REST calls into your custom scripts

## Installation
Follow the PowerShell instructions for the Install-Module cmdlet.

## Example
In just three lines you can have return all workspaces in your Relativity instance!

```
# Enter your user credentials
$cred = Get-Credentials
# Create a connection object
$con = New-ConnectionObject -RestHost 'my_relativity_host_name' -Credential $cred
# Return all workspaces
$results = Get-AllWorkspaces -Connection $con
```

## Compatibility
This module was created and tested on PowerShell version 5.1.14393.693 and has not be tested for earlier versions.

## Support
While this is an open source project on the kCura GitHub account, support is only available through the Relativity developer community. You are welcome to use the code and solution as you see fit within the confines of the license it is released under. However, if you are looking for support or modifications to the solution, we suggest reaching out to a Relativity Development Partner.
