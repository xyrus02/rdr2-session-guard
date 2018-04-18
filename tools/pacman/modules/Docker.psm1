function Update-DockerImage {

	[CmdLetBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)] $Package
	)
	
	process {
		if ($Package -eq $null) {
			Return
		}

		if (-not [string]::Equals($Package.GetType().BaseType.Name, "HierarchyLevel")) {
			Write-Error "Can't execute script for ""$Package"": not a valid package reference"
			Return
		}

		$refs = $Package.getPackages()
		
		foreach($ref in $refs) {
		
			$hash = $ref.Directory.FullName.getHashCode()
			$tempDir = Join-Path $global:System.RootDirectory "temp\build-context\$("{0:X8}" -f @($hash))"
			
			if (test-path $tempdir -pathType container) {
				remove-item $tempdir -force -recurse
			}
			
			$null = new-item $tempDir -itemType Directory
			
			$dockerConfig = $ref.EffectiveConfiguration.getObject().docker
				
			if ([string]::IsNullOrWhiteSpace($dockerConfig.tag)) {
				continue
			}
			
			if ($dockerConfig -eq $null) {
				continue
			}
			
			$includes = @($dockerConfig.buildContext.include) | where-object { $_ -ne $null } | foreach-object { join-path $ref.Directory.FullName $_ }
			$excludes = @($dockerConfig.buildContext.exclude) | where-object { $_ -ne $null } | foreach-object { join-path $ref.Directory.FullName $_ }
			
			$files = $includes | foreach-object { get-childitem -path $ref.directory.fullname -exclude $excludes }
			$files | foreach-object { copy-item -recurse -path $_.FullName -destination $tempDir }
			
			push-location $tempDir
			$cmd = "docker build $($dockerConfig.buildParams) --tag $($dockerConfig.tag) ."
			write-verbose "Executing: $cmd"
			$cmd | invoke-expression
			pop-location
			
			if (test-path $tempdir -pathType container) {
				remove-item $tempdir -force -recurse
			}
		}
	}
}

function Invoke-DockerScript {

	[CmdLetBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)] $Package,
		[Parameter(Mandatory = $true, Position = 0)] $Name
	)
	
	process {
		if ($Package -eq $null) {
			Return
		}

		if (-not [string]::Equals($Package.GetType().BaseType.Name, "HierarchyLevel")) {
			Write-Error "Can't execute script for ""$Package"": not a valid package reference"
			Return
		}

		$refs = $Package.getPackages()
		
		foreach($ref in $refs) {
		
			$commands = @($Package.EffectiveConfiguration.getObject().docker.scripts.$Name) | where-object { $_ -ne $null }
			
			foreach ($command in $commands) {
			    write-verbose "Executing: ""docker $command"""
				invoke-expression "docker $command"
			}
		}
	}
}

set-alias "host" "Invoke-DockerScript"
set-alias "deploy" "Update-DockerImage"

Export-ModuleMember `
-Function @(
    "Invoke-DockerScript",
    "Update-DockerImage"
) `
-Alias @(
    "deploy",
    "host"
)