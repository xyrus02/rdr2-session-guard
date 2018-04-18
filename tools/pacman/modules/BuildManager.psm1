function Invoke-Build {
    [CmdLetBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)] $Package,
        [Parameter(Mandatory = $false)] [string] $Target,
		[switch] $PassThru
    )

    begin {
        $buildEngine = $global:System.Environment.BuildEngine
        
        if ([string]::IsNullOrWhiteSpace($buildEngine)) {
            throw("The environment variable ""BuildEngine"" was not set. Please use the file ""config.json"" in the repository root to provide the variable for the loaded environment ""$(env)"".")
        }
        
        $buildEngineLauncher = Join-Path $PSScriptRoot "..\build\$buildEngine.ps1"

        if (-not (Test-Path $buildEngineLauncher -PathType Leaf)) {
            throw("An unknown or invalid build engine was selected: $buildEngine")
        }        
    }

    process {
        if ($Package -eq $null) {
            Return
        }

        if (-not [string]::Equals($Package.GetType().BaseType.Name, "HierarchyLevel")) {
            Write-Error "Can't build ""$Package"": not a valid package reference"
            Return
        }

        $refs = $Package.getPackages()
        $scope = Open-IsolationScope

        try {
            foreach($ref in $refs) {
                $build = $ref.EffectiveConfiguration.getChild("pacman").getChild("build").getObject()
    
                if ($build -eq $null) {
                    $build = [PSCustomObject] @{}
                }

                $buildParams = $build.parameters

                if ($buildParams -eq $null) {
                    $buildParams = @{}
                }
    
                if ($build.BeforeBuild -ne $null -and $pscmdlet.ShouldProcess("$($ref.Class)/$ref", "PreBuild")) {
                    Invoke-Isolated -Context $ref -Command $build.BeforeBuild -Scope $scope -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue")
                }
    
                $projectFilters = "$($build.Projects)".Split(@(";"), [StringSplitOptions]::RemoveEmptyEntries)
                $effectiveTarget = $build.Target
    
                if (-not [string]::IsNullOrWhiteSpace($Target)) {
                    $effectiveTarget = $Target
                }
    
                if ([string]::IsNullOrWhiteSpace($effectiveTarget)) {
                    $effectiveTarget = ""
                }
    
                $visited = New-Object "System.Collections.Generic.HashSet[System.String]"
    
                foreach($projectFilter in $projectFilters) {
                
                    $searchPath = Split-Path $projectFilter
    
                    if (-not [IO.Path]::IsPathRooted($searchPath)) {
                        $searchPath = Join-Path ($ref.Directory.FullName) $searchPath
                    }
    
                    $fileFilter = Split-Path -Leaf $projectFilter
                    $projectFiles = @($projectFilters | Foreach-Object { Get-ChildItem -path $searchPath -Filter $fileFilter -File })
    
                    foreach($projectFile in $projectFiles) {
                    
                        if (-not $visited.Add($projectFile.FullName)) {
                            continue
                        }
    
                        $targets = $effectiveTarget.Split(@(","), [StringSplitOptions]::RemoveEmptyEntries)

                        foreach($targetItem in $targets) {
                            if ([string]::IsNullOrWhiteSpace($targetItem)) {
                                continue
                            }

                            if ($pscmdlet.ShouldProcess("$($ref.Class)/$ref", "$($targetItem):$($projectFile.Name)")) {
                                &"$buildEngineLauncher" -Configuration $buildParams -Project $projectFile -Target $targetItem
                            }
                        }
                        
                    }
                }
            
                if ($build.AfterBuild -ne $null -and $pscmdlet.ShouldProcess("$($ref.Class)/$ref", "PostBuild")) {
                    Invoke-Isolated -Context $ref -Scope $scope -Command $build.AfterBuild -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue")
                }
            }
        }
        finally {
            Close-IsolationScope $scope
        }

        if ($PassThru) {
            Write-Output $Package
        }
    }
}

Set-Alias "build" "Invoke-Build"
Export-ModuleMember -Function @("Invoke-Build") -Alias @("build")