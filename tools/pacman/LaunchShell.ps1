param(
	[Parameter(Mandatory = $true, Position = 0)] [string] $RepositoryRoot,
	[Parameter(Mandatory = $true, Position = 1)] [string] $Environment,
	[Parameter(Mandatory = $false)] [switch] $Headless,
	[Parameter(Mandatory = $false)] [switch] $Silent
)

# These modules are required by this script so we import them here. They will be unloaded and reloaded when calling "Initialize-Shell"
Import-Module "$PSScriptRoot\modules\Environment.psm1"
Import-Module "$PSScriptRoot\modules\Configuration.psm1"
Import-Module "$PSScriptRoot\modules\Isolation.psm1"
Import-Module "$PSScriptRoot\modules\TemplateEngine.psm1"
Import-Module "$PSScriptRoot\modules\PackageManager.psm1"

# Globals
$global:System = @{
	RootDirectory   = $RepositoryRoot
	IsHeadlessShell = $Headless
	Version         = (New-PropertyContainer "$PSScriptRoot\system.json").getProperty("Version")
	Environment     = @{}
	Modules         = $null
}

$global:Environment = $Environment

# Definitions
class ModuleContainer {

	hidden [System.Collections.Generic.HashSet[System.String]] $_Modules
	
	ModuleContainer() {
		$this._Modules = New-Object System.Collections.Generic.HashSet[System.String]
	}

	[bool] load($Name, $ModulePath, $Silent) {
	
		if ([string]::IsNullOrWhiteSpace($Name)) {
			return $false
		}
		
		if ([string]::IsNullOrWhiteSpace($ModulePath)) {
			return $false
		}

		if (-not $Silent) { Write-Host -NoNewLine "Loading module ""$Name""..." }
		
		try {
			$ErrorActionPreference = "Stop"
		
			if (-not (Test-Path -PathType Leaf -Path $ModulePath)) {
				throw "The module is not installed."
			}
			
			Import-Module "$ModulePath"
		} 
		catch {
			if (-not $Silent) { Write-Host -ForegroundColor Red "FAILED: $($_.Exception.Message)" }
			return $false
		}
		
		if (-not $Silent) { Write-Host -ForegroundColor Green "OK" }
		$null = $this._Modules.Add($Name.ToLower())
		
		return $true
	}
	[bool] isLoaded($Name) {
		if ([string]::IsNullOrWhiteSpace($Name)) {
			return $false
		}
	
		return $this._Modules.Contains($Name.ToLower())
	}
}

function Initialize-Shell { 
	Remove-Variable * -ErrorAction SilentlyContinue
	Remove-Module *

	$error.Clear()

	$PreviousErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	if (-not $Silent) { write-host "" }
	
	$classPaths = @(
		(Join-Path $PSScriptRoot   modules),
		(Join-Path $RepositoryRoot modules)
	)
	
	$classes = @($classPaths | ? { Test-Path $_ -PathType Container } | %{ Get-ChildItem -filter "*.psm1" -path $_ })
	$success = $true
	
	$global:System.Modules = New-Object ModuleContainer
	$ErrorActionPreference = "Stop"
	
	foreach($class in $classes) 
	{
		$success = $success -and ($global:System.Modules.load($class.BaseName, $class.FullName, $Silent))
	}
	
	if (-not $Silent) { Write-Host "" }

	$ErrorActionPreference = $PreviousErrorActionPreference
	$PreviousErrorActionPreference = $null
	
	if ($null -ne (Get-Command "Set-Environment" -ErrorAction SilentlyContinue)) {
		Set-Environment -TargetEnvironment $Environment | Out-Null
	}
} 

# Shell prompt
function prompt {
    $pl = (([IO.DirectoryInfo](Get-Location).Path).FullName).TrimEnd("\")
    $pb = (([IO.DirectoryInfo]$global:System.RootDirectory).FullName).TrimEnd("\")
    
    if ($pl.StartsWith($pb)) {
        $pl = $pl.Substring($pb.Length).TrimStart("\")
    }

    Write-Host ("$pl `$".Trim()) -nonewline -foregroundcolor White
    return " "
}

# Logic when executing initially
if (-not $global:System.IsHeadlessShell) {
	Set-Environment -TargetEnvironment $Environment | Out-Null
	
	$displayTitle = $global:Repository.EffectiveConfiguration.getProperty("Title")
        
	if ([string]::IsNullOrWhiteSpace($displayTitle)) {
		$displayTitle = "$(([IO.DirectoryInfo] $global:System.RootDirectory).Name)"
	}

    if (-not $Silent) {
	    write-host -ForegroundColor cyan -NoNewline $displayTitle
	    write-host -ForegroundColor white " Developer Shell"
	    write-host -ForegroundColor white "Version $($global:System.Version)"
	}
	
	$licenseFiles = @(
		'LICENSE',
		'LICENSE.txt'
	)

	if (-not $Silent) {
        foreach($licenseFile in $licenseFiles) {
            $licenseFullPath = Join-Path $PSScriptRoot "..\..\$licenseFile"
            if (Test-Path -PathType Leaf $licenseFullPath) {
                $licenseText = (Get-Content -Raw $licenseFullPath | Expand-Template).Trim(@("`r","`n"))
                write-host -ForegroundColor Gray "`n$licenseText"
            }
        }
	}
}

Set-Alias -Name reboot -Value Initialize-Shell
Initialize-Shell
