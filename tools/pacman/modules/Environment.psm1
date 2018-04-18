function Get-Environment { return Set-Environment }

function Set-Environment {
	param([Parameter(ValueFromPipeline = $true, Position = 0)] [string] $TargetEnvironment)

	$config = (New-PropertyContainer (Join-Path $global:System.RootDirectory "config.json")).getObject()

	if ([string]::IsNullOrWhiteSpace($TargetEnvironment)) {
		return $global:Environment
	}
	
	$env = $config.$TargetEnvironment
	
	if ($env -eq $null) {
		$env = @{}
	}
	
	$global:System.Environment = $env
	$global:Environment = $TargetEnvironment
	
	if ([string]::IsNullOrWhiteSpace($global:System.Environment.DefaultRepository)) { 
		$global:System.Environment.DefaultRepository = "src"
	}

	$global:Repository = Get-PackageRepository

	if (-not $global:System.IsHeadlessShell) {
        $displayTitle = $global:Repository.EffectiveConfiguration.getProperty("Title")
        
        if ([string]::IsNullOrWhiteSpace($displayTitle)) {
            $displayTitle = "$(([IO.DirectoryInfo] $global:System.RootDirectory).Name) ($($global:Repository.Name))"
        }
        if ([string]::IsNullOrWhiteSpace($displayTitle)) {
            $displayTitle = "<unknown repository>"
        }

		Invoke-Expression -Command "`$host.ui.RawUI.WindowTitle = 'PACMAN - $displayTitle'" -ErrorAction SilentlyContinue
	}

	return $TargetEnvironment
}

Set-Alias -Name env -Value Set-Environment

Export-ModuleMember `
-Function @(
    "Set-Environment",
    "Get-Environment"
) `
-Alias @(
    "env"
)