$localPath = (Get-Item -Path ".").FullName

Import-Module -Name (Join-Path $localPath '\SharedRESTFunctions')
Import-Module -Name (Join-Path $localPath '\RelativityRESTModule')
Import-Module -Name (Join-Path $localPath '\RelativityUnsupportedRESTModule')