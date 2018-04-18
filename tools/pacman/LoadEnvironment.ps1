param(
	[Parameter(Mandatory = $false, Position = 0)] [string] $Environment,
	[switch] $Silent
)

Import-Module "$PSScriptRoot\modules\Configuration.psm1"
$RepositoryRoot = [IO.Path]::GetFullPath("$PSScriptRoot\..\..\")

if ([string]::IsNullOrWhiteSpace($Environment)) {
    $Environment = (New-PropertyContainer "$RepositoryRoot\config.json").getProperty("DefaultEnvironment")
}

."$PSScriptRoot\LaunchShell.ps1" -RepositoryRoot $RepositoryRoot -Environment $Environment -Headless -Silent:$Silent