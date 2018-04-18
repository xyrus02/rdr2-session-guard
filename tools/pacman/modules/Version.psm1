Add-Type -Path "$PSScriptRoot\bin\XyrusWorx.Foundation.dll"
Add-Type -Path "$PSScriptRoot\bin\XyrusWorx.Shell.Versioning.dll"

function Deserialize-Version {
    param([Parameter(ValueFromPipeline = $true, Position = 0)] [string] $VersionString)

    if ([string]::IsNullOrWhiteSpace($VersionString)) {
        return (New-Object XyrusWorx.SemanticVersion)
    }

	return [XyrusWorx.SemanticVersion]::Parse($VersionString)
}
function Serialize-Version {
    param([Parameter(ValueFromPipeline = $true)] [XyrusWorx.SemanticVersion] $Version)

    if ($Version -eq $null) {
        return (New-Object XyrusWorx.SemanticVersion)
    }

	return $Version.ToString()
}

function New-Version {
    param([Parameter(Position = 0)] [UInt16] $Major,
          [Parameter(Position = 1)] [UInt16] $Minor,
          [Parameter(Position = 2)] [UInt16] $Patch,
          [Parameter()] $PreRelease,
          [Parameter()] $Build)

    $PreRelease = [string[]] @($PreRelease)
    $Build = [string[]] @($Build)
    $Version = New-Object XyrusWorx.SemanticVersion -ArgumentList @($Major, $Minor, $Patch)

    if ($PreRelease -ne $null -and $PreRelease.Length -gt 0) { $Version = $Version.DeclarePreRelease($PreRelease) }
    if ($Build -ne $null -and $Build.Length -gt 0) { $Version = $Version.WithMetadata($Build) }

    return $Version.ToString()
}
function Test-Version {
    param([Parameter(ValueFromPipeline = $true, Position = 0)] [string] $VersionString)

    $result = New-Object XyrusWorx.SemanticVersion
    if (-not ([XyrusWorx.SemanticVersion]::TryParse($VersionString, [ref] $result))) {
        return $false
    }

    return $true
}
function Update-Version {
    param([Parameter(ValueFromPipeline = $true, Position = 0)] [string] $Version,
          [Parameter()] [Int32] $Major = -1,
          [Parameter()] [Int32] $Minor = -1,
          [Parameter()] [Int32] $Patch = -1,
          [Parameter()] $PreRelease = $null,
          [Parameter()] $Build = $null)

    if ([string]::IsNullOrWhiteSpace($Version)) {
        $Version = "0.0.0"
    }

    $VersionObj = [XyrusWorx.SemanticVersion] (Deserialize-Version $Version)

    if ($Major -lt 0) { $Major = $VersionObj.Major }
    if ($Minor -lt 0) { $Minor = $VersionObj.Minor }
    if ($Patch -lt 0) { $Patch = $VersionObj.PatchNumber }

    $PreRelease = [string]::Join(".",[string[]] @([string]::Join(".", $VersionObj.PreReleaseIdentifiers), [string]::Join(".", @($PreRelease)))).Split(".", [System.StringSplitOptions]::RemoveEmptyEntries)
    $Build = [string]::Join(".",[string[]] @([string]::Join(".", $VersionObj.BuildMetadata), [string]::Join(".", @($Build)))).Split(".", [System.StringSplitOptions]::RemoveEmptyEntries)
    $VersionObj = New-Object XyrusWorx.SemanticVersion -ArgumentList @($Major, $Minor, $Patch)

    if ($PreRelease -ne $null -and $PreRelease.Length -gt 0) { $VersionObj = $VersionObj.DeclarePreRelease($PreRelease) }
    if ($Build -ne $null -and $Build.Length -gt 0) { $VersionObj = $VersionObj.WithMetadata($Build) }

    return $VersionObj.ToString()
}
function Add-Version {
    param([Parameter(ValueFromPipeline = $true, Position = 0)] [string] $Version,
          [Parameter()] [switch] $Major,
          [Parameter()] [switch] $Minor,
          [Parameter()] [switch] $Patch,
          [Parameter()] [UInt16] $MajorStep = 0,
          [Parameter()] [UInt16] $MinorStep = 0,
          [Parameter()] [UInt16] $PatchStep = 0)

    if ([string]::IsNullOrWhiteSpace($Version)) {
        $Version = "0.0.0"
    }

    $VersionObj = [XyrusWorx.SemanticVersion] (Deserialize-Version $Version)

    if ($MajorStep -lt 0) { $MajorStep = 0 }
    if ($MinorStep -lt 0) { $MinorStep = 0 }
    if ($PatchStep -lt 0) { $PatchStep = 0 }

    if ($MajorStep -eq 0 -and $Major) { $MajorStep = 1 }
    if ($MinorStep -eq 0 -and $Minor) { $MinorStep = 1 }
    if ($PatchStep -eq 0 -and $Patch) { $PatchStep = 1 }

    for($i = 0; $i -lt $MajorStep; $i ++) { $VersionObj = $VersionObj.RaiseMajor() }
    for($i = 0; $i -lt $MinorStep; $i ++) { $VersionObj = $VersionObj.RaiseMinor() }
    for($i = 0; $i -lt $PatchStep; $i ++) { $VersionObj = $VersionObj.Patch() }

    return $VersionObj.ToString()
}
function Remove-VersionPrerelease {
    param([Parameter(ValueFromPipeline = $true, Position = 0)] [string] $Version)

    if ([string]::IsNullOrWhiteSpace($Version)) {
        $Version = "0.0.0"
    }

    $VersionObj = [XyrusWorx.SemanticVersion] (Deserialize-Version $Version)
    $VersionObj = $VersionObj.DeclareFinal()

    return $VersionObj.ToString()
}
function Remove-VersionMetadata {
    param([Parameter(ValueFromPipeline = $true, Position = 0)] [string] $Version)

    if ([string]::IsNullOrWhiteSpace($Version)) {
        $Version = "0.0.0"
    }

    $VersionObj = [XyrusWorx.SemanticVersion] (Deserialize-Version $Version)
    $VersionObj = $VersionObj.WithoutMetadata()

    return $VersionObj.ToString()
}

Export-ModuleMember -Function @(
    "New-Version",
    "Test-Version",
    "Update-Version",
    "Add-Version",
    "Remove-VersionPrerelease",
    "Remove-VersionMetadata"
)
