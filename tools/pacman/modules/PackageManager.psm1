class HierarchyLevel {
	[ValidateNotNullOrEmpty()] [String]               $Name
	[ValidateNotNullOrEmpty()] [IO.DirectoryInfo]     $Directory
	
	[ValidateNotNullOrEmpty()] $Configuration
	[ValidateNotNullOrEmpty()] $EffectiveConfiguration
	
	[Package[]] getPackages() {
		throw("Must be used in overriden class")
	}
	
	[string] ToString() {
		return $this.Name
	}
}

class PackageRepository : HierarchyLevel {
	[Package[]] getPackages() {
		return @(Get-Package -Filter "$($this.Directory.Name):*/*")
	}
}

class PackageClass : HierarchyLevel {
	[ValidateNotNullOrEmpty()] [PackageRepository] $Repository
	
	[Package[]] getPackages() {
		return @(Get-Package -Filter "$($this.Repository.Directory.Name):$($this.Name)/*")
	}
}

class Package : HierarchyLevel {
	[ValidateNotNullOrEmpty()] [PackageRepository] $Repository
	[ValidateNotNullOrEmpty()] [PackageClass]      $Class
	
	[Package[]] getPackages() {
		return @($this)
	}
}

####################### Utility functions #######################

function Test-ArbitaryToken { 
	param([string] $Id, [char[]] $IllegalChars = [IO.Path]::GetInvalidFileNameChars()) 
	return("$Id".ToCharArray() | Where-Object{(New-Object string @(,$IllegalChars)).Contains("$_")}).Count -eq 0
}

function Get-PropertyPathTokens {
	param([string] $PropertyPath)

	if ([string]::IsNullOrWhiteSpace($PropertyPath)) {
		return @()
	}

	$chars = "$PropertyPath".Trim(@("/", "`r", "`n", "`t")).ToCharArray()
	$quote = $false
	$acc = ""

	$tokens = New-Object "System.Collections.Generic.List[System.String]"

	for($i = 0; $i -lt $chars.Length; $i++){
		$c = $chars[$i]
		$cn = [char]0
		
		if ($i -lt $chars.Length - 1) {
			$cn = $chars[$i + 1]
		}

		if ($c -eq """") {
			if (($acc.Length -eq 0) -or ([int]$cn -eq 0) -or ($cn -eq "/")) {
				$quote = -not $quote
			} 
            $acc += """" # we carry the quote to the output expression
		} 
		elseif ([int]$c -le 32) {
			if ($quote){
				$acc += $c
			}
			else {
				continue # white-space outside quote? ignore!
			}
		} 
		elseif ($c -eq "/") {
			if ($quote){
				$acc += $c
			} 
			else {
				if (-not [string]::IsNullOrWhiteSpace($acc)) {
					$tokens.Add($acc)
					$acc = ""
				}
			}
		}
		else {
			$acc += $c
		}
	}

    if (-not [string]::IsNullOrWhiteSpace($acc)) {
		$tokens.Add($acc)
	}

	return @($tokens)
}

####################### External functions ######################

function Get-PackageConfiguration {
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)] [HierarchyLevel] $Node
	)
	
	process {
		Write-Output $Node.EffectiveConfiguration.getObject()
	}
}

function Get-PackageRepository {
	param(
		[Parameter(Mandatory = $false, Position = 0)] [string] $Id
	)
	
	if ([string]::IsNullOrWhiteSpace($Id)) {
		$Id = $global:System.Environment.DefaultRepository
	}

	$SolutionRoot = Join-Path $global:System.RootDirectory $Id
	
	if ($Id -ne $global:System.Environment.DefaultRepository) {
		$Prefix = "$($Id):"
		$Suffix = " ($($Id))"
	}
	else {
		$Prefix = ""
		$Suffix = ""
	}
	
	$PackageRepositoryFolder = [IO.DirectoryInfo] $SolutionRoot
	$PackageRepositoryConfiguration = New-PropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.json")
	
	$PackageRepository = [PackageRepository] @{
		Name = $Id
		Directory = $PackageRepositoryFolder
		Configuration = $PackageRepositoryConfiguration
		EffectiveConfiguration = New-MergeContainer @($PackageRepositoryConfiguration) -PackageId $Id
	}

	return $PackageRepository
}

function Get-PackageClass {
	param(
		[Parameter(Mandatory = $false, Position = 0)] [string] $Filter = $null
	)

	if ([string]::IsNullOrWhiteSpace($Filter)) {
		$Filter = "*"
	}
	
	if ($Filter.Contains(":")) {
		$Tokens = $Filter.Split(@(":"), 2, [StringSplitOptions]::RemoveEmptyEntries)

		if ($Tokens.Length -eq 1) {
			$Filter = $Tokens[0]
			$RepositoryId = $global:System.Environment.DefaultRepository
		} else {
			$Filter = $Tokens[1]
			$RepositoryId = $Tokens[0]
		}
	} else {
		$RepositoryId = $global:System.Environment.DefaultRepository
	}
	
	$SolutionRoot = Join-Path $global:System.RootDirectory $RepositoryId

	if (-not (Test-Path $SolutionRoot -PathType Container)) {
		$Candidates = @()
	} else {
		$Candidates = @(Get-ChildItem -Path $SolutionRoot -Directory -Filter $Filter)
	}
	
	if ($RepositoryId -ne $global:System.Environment.DefaultRepository) {
		$Prefix = "$($RepositoryId):"
		$Suffix = " ($($RepositoryId))"
	}
	else {
		$Prefix = ""
		$Suffix = ""
	}

	if ($Candidates.Length -eq 0) {
		if (-not (Test-ArbitaryToken -Id $Filter -IllegalChars @("*", "?"))) {
			return
		}

		$PackageClassFolder = [IO.DirectoryInfo] (Join-Path $SolutionRoot $Filter)
		$PackageClassConfiguration = New-PropertyContainer (Join-Path $PackageClassFolder.FullName "package.json")
		
		$PackageRepositoryFolder = [IO.DirectoryInfo] $SolutionRoot
		$PackageRepositoryConfiguration = New-PropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.json")
		
		$PackageRepository = [PackageRepository] @{
			Name = $RepositoryId
			Directory = $PackageRepositoryFolder
			Configuration = $PackageRepositoryConfiguration
			EffectiveConfiguration = New-MergeContainer @($PackageRepositoryConfiguration) -PackageId $RepositoryId
		}
		
		$PackageClass = [PackageClass] @{
			Name = $PackageClassFolder.Name
			Directory = $PackageClassFolder
			Repository = $PackageRepository
			Configuration = $PackageClassConfiguration
			EffectiveConfiguration = New-MergeContainer @($PackageClassConfiguration, $PackageRepositoryConfiguration) -PackageId "$Prefix$($PackageClassFolder.Name)/*"
		}

		return @($PackageClass)
	}

	foreach($Candidate in $Candidates) {

		$PackageClassFolder = [IO.DirectoryInfo]$Candidate
		$PackageClassConfiguration = New-PropertyContainer (Join-Path $PackageClassFolder.FullName "package.json")
		
		$PackageRepositoryFolder = $PackageClassFolder.Parent
		$PackageRepositoryConfiguration = New-PropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.json")
		
		$PackageRepository = [PackageRepository] @{
			Name = "$($PackageRepositoryFolder.Parent.Name)$Suffix"
			Directory = $PackageRepositoryFolder
			Configuration = $PackageRepositoryConfiguration
			EffectiveConfiguration = New-MergeContainer @($PackageRepositoryConfiguration) -PackageId $RepositoryId
		}
		
		$PackageClass = [PackageClass] @{
			Name = $PackageClassFolder.Name
			Directory = $PackageClassFolder
			Repository = $PackageRepository
			Configuration = $PackageClassConfiguration
			EffectiveConfiguration = New-MergeContainer @($PackageClassConfiguration, $PackageRepositoryConfiguration) -PackageId "$Prefix$($PackageClassFolder.Name)/*"
		}

		Write-Output $PackageClass
	}
}

function Get-Package {
	param(
		[Parameter(Mandatory = $false, Position = 0)] [string] $Filter 
	)

	if ([string]::IsNullOrWhiteSpace($Filter)) {
		$Filter = "*"
	}
	
	if ([string]::IsNullOrWhiteSpace($Filter)) {
		$Filter = "*"
	}
	
	if ($Filter.Contains(":")) {
		$Tokens = $Filter.Split(@(":"), 2, [StringSplitOptions]::RemoveEmptyEntries)

		if ($Tokens.Length -eq 1) {
			$Filter = $Tokens[0]
			$RepositoryId = $global:System.Environment.DefaultRepository
		} else {
			$Filter = $Tokens[1]
			$RepositoryId = $Tokens[0]
		}
	} else {
		$RepositoryId = $global:System.Environment.DefaultRepository
	}
	
	$SolutionRoot = Join-Path $global:System.RootDirectory $RepositoryId

	if ($Filter.Contains("/")) {
		$Tokens = $Filter.Split(@("/"), 2, [StringSplitOptions]::RemoveEmptyEntries)

		if ($Tokens.Length -eq 1) {
			$Name = $Tokens[0]
			$Class = "*"
		} else {
			$Name = $Tokens[1]
			$Class = $Tokens[0]
		}
	} else {
		$Name = $Filter
		$Class = "*"
	}

	if (-not (Test-Path $SolutionRoot -PathType Container)) {
		$Candidates = @()
	} else {
		$Candidates = @( `
			Get-ChildItem -Path $SolutionRoot -Directory -Filter $Class | Foreach-Object { `
			Get-ChildItem -Path $_.FullName -Directory -Filter $Name })
	}
		
	if ($RepositoryId -ne $global:System.Environment.DefaultRepository) {
		$Prefix = "$($RepositoryId):"
		$Suffix = " ($($RepositoryId))"
	}
	else {
		$Prefix = ""
		$Suffix = ""
	}

	if ($Candidates.Length -eq 0) {
		if (-not (Test-ArbitaryToken -Id "$Class\$Name" -IllegalChars @("*", "?"))) {
			return
		}

		$PackageFolder = [IO.DirectoryInfo] (Join-Path $SolutionRoot "$Class\$Name")
		$PackageConfiguration = New-PropertyContainer (Join-Path $PackageFolder.FullName "package.json")

		$PackageClassFolder = [IO.DirectoryInfo] (Join-Path $SolutionRoot "$Class")
		$PackageClassConfiguration = New-PropertyContainer (Join-Path $PackageClassFolder.FullName "package.json")
		
		$PackageRepositoryFolder = [IO.DirectoryInfo] $SolutionRoot
		$PackageRepositoryConfiguration = New-PropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.json")
		
		$PackageRepository = [PackageRepository] @{
			Name = $RepositoryId
			Directory = $PackageRepositoryFolder
			Configuration = $PackageRepositoryConfiguration
			EffectiveConfiguration = New-MergeContainer @($PackageRepositoryConfiguration) -PackageId $RepositoryId
		}
		
		$PackageClass = [PackageClass] @{
			Name = $PackageClassFolder.Name
			Directory = $PackageClassFolder
			Repository = $PackageRepository
			Configuration = $PackageClassConfiguration
			EffectiveConfiguration = New-MergeContainer @($PackageClassConfiguration, $PackageRepositoryConfiguration) -PackageId "$Prefix$($PackageClassFolder.Name)/*"
		}

		$Package = [Package] @{
			Name = $PackageFolder.Name
			Directory = $PackageFolder
			Repository = $PackageRepository
			Class = $PackageClass
			Configuration = $PackageConfiguration
			EffectiveConfiguration = New-MergeContainer @($PackageConfiguration, $PackageClassConfiguration, $PackageRepositoryConfiguration) -PackageId "$Prefix$($PackageClassFolder.Name)/$($PackageFolder.Name)"
		}

		return @($Package)
	}

	foreach($Candidate in $Candidates) {
		
		$PackageFolder = [IO.DirectoryInfo]$Candidate
		$PackageConfiguration = New-PropertyContainer (Join-Path $PackageFolder.FullName "package.json")
		
		$PackageClassFolder = $PackageFolder.Parent
		$PackageClassConfiguration = New-PropertyContainer (Join-Path $PackageClassFolder.FullName "package.json")
		
		$PackageRepositoryFolder = $PackageClassFolder.Parent
		$PackageRepositoryConfiguration = New-PropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.json")
		
		$PackageRepository = [PackageRepository] @{
			Name = "$($PackageRepositoryFolder.Parent.Name)$Suffix"
			Directory = $PackageRepositoryFolder
			Configuration = $PackageRepositoryConfiguration
			EffectiveConfiguration = New-MergeContainer @($PackageRepositoryConfiguration) -PackageId $Prefix.TrimEnd(":")
		}
		
		$PackageClass = [PackageClass] @{
			Name = $PackageClassFolder.Name
			Directory = $PackageClassFolder
			Repository = $PackageRepository
			Configuration = $PackageClassConfiguration
			EffectiveConfiguration = New-MergeContainer @($PackageClassConfiguration, $PackageRepositoryConfiguration) -PackageId "$Prefix$($PackageClassFolder.Name)/*"
		}
		
		$Package = [Package] @{
			Name = $PackageFolder.Name
			Directory = $PackageFolder
			Repository = $PackageRepository
			Class = $PackageClass
			Configuration = $PackageConfiguration
			EffectiveConfiguration = New-MergeContainer @($PackageConfiguration, $PackageClassConfiguration, $PackageRepositoryConfiguration) -PackageId "$Prefix$($PackageClassFolder.Name)/$($PackageFolder.Name)"
		}
		
		Write-Output $Package
	}
}

function Get-RepositoryItem {
	param(
		[Parameter(Mandatory = $false, Position = 0)] [string] $Filter 
	)

	if ([string]::IsNullOrWhiteSpace($Filter)) {
		return Get-PackageRepository
	}

	if ($Filter.Trim() -eq ":" -or $Filter.Trim() -eq "/") {
		return @()
	}

	if ($Filter.Trim().EndsWith(":")) { # e.g. "src:"
		return Get-PackageRepository -Id $Filter.Trim().TrimEnd(":")
	}

	if ($Filter.Trim().StartsWith("/")) { # e.g. "/app"
		return Get-Package -Filter "*/$($Filter.Trim().TrimStart("/"))"
	}

	if ($Filter.Trim().EndsWith("/")) { # e.g. "app/"
		return Get-PackageClass -Filter "$($Filter.Trim().TrimEnd("/"))/*"
	}

	if ($Filter.Contains("/")) { # e.g. "app/package"
		return Get-Package -Filter $Filter
	}

	if ($Filter.Contains(":")) { # e.g. "src:app"
		return Get-PackageClass -Filter $Filter
	}

	# rest, e.g. "app"
	return Get-PackageClass -Filter $Filter 
}

function Initialize-Package {
	[CmdLetBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)] [Package] $Package,
		[Parameter(Position = 0, Mandatory = $false)] [string] $Template,
		[Parameter(Mandatory = $false)] [System.Collections.Hashtable] $Properties = $null,
		[switch] $Overwrite,
		[switch] $Force
	)

	process {
		if ($Package -eq $null) {
			return
		}

		if (-not [string]::Equals($Package.GetType().BaseType.Name, "HierarchyLevel")) {
            Write-Error "Can't initialize ""$Package"": not a valid package reference"
            Return
        }

		$defaultTemplate = $Package.Class.EffectiveConfiguration.getProperty("DefaultTemplate")
		
		if ([string]::IsNullOrWhiteSpace($Template)) {
			$Template = $defaultTemplate
		}
	
		$templateSearchPaths = @(
			"templates",
			"tools\pacman\templates"
		)
		$templateExtensions = @(
			"template",
			"zip"
		)
	
		$foundTemplateFile = $null
	
		if(-not [string]::IsNullOrWhiteSpace($Template)){
			foreach($templateSearchPath in $templateSearchPaths) {
				foreach($templateExtension in $templateExtensions) { 

					$templateFile = Join-Path $global:System.RootDirectory "$templateSearchPath\$Template.$templateExtension"
					$templateDir = Join-Path $global:System.RootDirectory "$templateSearchPath\$Template"
	
					if (Test-Path $templateDir -PathType Container) {
						$foundTemplateFile = $templateDir
						break
					}
	
					if (Test-Path $templateFile -PathType Leaf) {
						$foundTemplateFile = $templateFile
						break
					}
				}
				
				if ($foundTemplateFile -ne $null) {
					break
				}
			}
	
			if ($foundTemplateFile -eq $null) {
				Write-Error "Unable to find template ""$Template""."
				return
			}
		}

		if ($pscmdlet.ShouldProcess("$($Package.Class)/$Package", "Init:CreateDirectory")) {
			$null = $Package.Directory.Create()
		}

		if ($Package.Directory.Exists) {
			$preExistingFiles = @(Get-ChildItem $Package.Directory.FullName -File -Recurse).Length -gt 0
		}
		else {
			$preExistingFiles = @()
		}
	
		if ($pscmdlet.ShouldProcess("$($Package.Class)/$Package", "Init:CreatePackageConfiguration")) {
			$packageProps = New-PropertyContainer -Force (Join-Path $Package.Directory.FullName "package.json")
	
			$packageProps.setProperty("name", $Package.Name)
			$packageProps.setProperty("version", "0.1.0")
			$packageProps.setProperty("description", $Package.Name)
		}
	
		if ($foundTemplateFile -ne $null) {
	
			if (-not $Force -and $preExistingFiles) {
				Write-Error "The package directory ""$($Package.Directory.FullName)"" is not empty. If you wish to apply the template anyway, add the switch ""Force""."
				Return
			}
	
			if ($pscmdlet.ShouldProcess("$($Package.Class)/$Package", "Init:ExpandTemplate(""$foundTemplateFile"")")) {
				$templateContext = @{
					"Package" = $Package
					"Properties" = [PSCustomObject] $Properties
					"Metadata" = (New-PropertyContainer (Join-Path $Package.Directory.FullName "package.json"))
				}
	
				if ($templateContext.Properties -eq $null) {
					$templateContext.Properties = @{ }
				}

				Expand-TemplatePackage -TemplateFile $foundTemplateFile -Destination $Package.Directory.FullName -Force:$Overwrite -Context $templateContext -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue")
			}
		}

		Write-Output $Package
	}
}

function Get-PackageProperty {
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)] [HierarchyLevel] $Package,
		[Parameter(Mandatory = $true, Position = 0)] [string] $Property
	)
	
	process {
		if ($Package -eq $null) {
			Return
		}

		if (-not [string]::Equals($Package.GetType().BaseType.Name, "HierarchyLevel")) {
            Write-Error "Can't read ""$Package"": not a valid package reference"
            Return
		}
		
		$tokens = Get-PropertyPathTokens -PropertyPath $Property
		
		if ($tokens -eq $null -or $tokens.Length -eq 0) {
			Return
		}
	
		Write-Verbose "Tokenizer result: $($tokens -join " -> ")"

		try {
			$propScript = [ScriptBlock]::Create("`$_.$(@($tokens) -join ".")")
		} 
		catch {
			Write-Error "Invalid property path: $PropertyPath"
			Return
		}

		$Package.EffectiveConfiguration.getObject() | Foreach-Object -Process $propScript | Write-Output
	}
}

function Set-PackageProperty {
	[CmdLetBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)] $Package,
		[Parameter(Mandatory = $true, Position = 0)] [string] $Property,
		[Parameter(Mandatory = $false, Position = 1)] [string] $Value
	)
	
	process {
		if ($Package -eq $null) {
			Return
		}

		if (-not [string]::Equals($Package.GetType().BaseType.Name, "HierarchyLevel")) {
            Write-Error "Can't update ""$Package"": not a valid package reference"
            Return
		}
		
		if (-not $Package.Directory.Exists) {
			if ($pscmdlet.ShouldProcess("$($Package.Class)/$Package", "Config:InitPackage")) {
				if ($Package -is [Package]){
					$null = $Package | init
				}
				else {
					$null = New-Item -ItemType Directory -Path $Package.Directory.FullName
				}
			}
		}

		$tokens = @(Get-PropertyPathTokens -PropertyPath $Property)

		if ($tokens -eq $null -or $tokens.Length -eq 0) {
			Return
		}

		$head = @($tokens | Select-Object -SkipLast 1)
		$tail = $tokens | Select-Object -Last 1
		$node = $Package.Configuration

		if ($tail -eq $null) {
			Return
		}

		Write-Verbose "Tokenizer result: $($tokens -join " -> ")"

		foreach($token in $head) {
			$node = $node.getChild($token)
		}

		if ($pscmdlet.ShouldProcess("$($Package.Class)/$Package", "Config:WriteValue")) {
			$node.setProperty($tail, $Value)
		}
		
		Write-Output $Package
	}
}

####################### Aliases / Exports ######################

Set-Alias "pkg"  "Get-RepositoryItem"
Set-Alias "ppkg" "Get-Package"
Set-Alias "pcls" "Get-PackageClass"
Set-Alias "repo" "Get-PackageRepository"
Set-Alias "pcfg" "Get-PackageConfiguration"
Set-Alias "pget" "Get-PackageProperty"
Set-Alias "pset" "Set-PackageProperty"
Set-Alias "init" "Initialize-Package"

Export-ModuleMember -Function @(
	"Get-Package",
	"Get-PackageClass",
	"Get-PackageRepository",
	"Get-RepositoryItem",
	"Get-PackageProperty",
	"Get-PackageConfiguration",
	"Set-PackageProperty",
	"Initialize-Package"
) -Alias @(
	"pkg",
	"ppkg",
	"pcls",
	"repo",
	"prop",
	"pcfg",
	"init",
	"pget",
	"pset"
)