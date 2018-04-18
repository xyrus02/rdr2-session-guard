param(
    [Parameter(Mandatory = $true)] $Project,
    [Parameter(Mandatory = $true)] $Target,
    [Parameter(Mandatory = $true)] $Configuration
)

$buildTools = $global:System.Environment.BuildToolsPath

if ([string]::IsNullOrWhiteSpace($buildTools)) {
    throw("The environment variable ""BuildToolsPath"" was not set. Please use the file ""config.json"" in the repository root to provide the variable for the loaded environment ""$(env)"".")
}

$dotnetExecutable = Join-Path $buildTools "dotnet.exe"
$msbuildCommandLine = "/v:minimal /nologo /consoleloggerparameters:""NoSummary;ForceNoAlign"" /t:""$Target"" "

if (-not (Test-Path $dotnetExecutable -PathType Leaf)) {
    throw("The .NET CLI (dotnet.exe) was not found at the provided build tools path: $($buildTools)")
}

$elr = [regex]::new("^(?:.*?)(?:\(\d+,\d+\))?:\s+error\s+(?:[A-Z]+\d+)?:\s(.*?)$", "IgnoreCase")
$wlr = [regex]::new("^(?:.*?)(?:\(\d+,\d+\))?:\s+warning\s+(?:[A-Z]+\d+)?:\s(.*?)$", "IgnoreCase")

[IO.FileInfo] $projectFile = $Project

Write-Information "Starting build for project: $($projectFile.FullName)"

$Configuration | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" } | Select-Object -ExpandProperty Name | Foreach-Object {
    $msbuildCommandLine = "$msbuildCommandLine/p:$_=""$($Configuration.$_)"" "
}

$msbuildCommandLine = "$msbuildCommandLine""$($projectFile.FullName)"""

Write-Verbose ".NET CLI executable: $dotnetExecutable"
Write-Verbose "MSBuild command line: $msbuildCommandLine"

$errorCount = 0
"&""$dotnetExecutable"" msbuild $msbuildCommandLine" | Invoke-Expression | Foreach-Object {

    $elm = $elr.Match($_)
    $wlm = $wlr.Match($_)

    if ($elm.Success) {
        $errorCount ++
        Write-Error -Message $elm.Groups[1].Value -Category FromStdErr
    }
    elseif ($wlm.Success) {
        Write-Warning -Message $wlm.Groups[1].Value
    }
    else {
        Write-Information $_.TrimStart()
    }
}

if (($errorCount -le 0) -and ($LASTEXITCODE -ne 0)) {
    throw("Build failed with exit code $LASTEXITCODE for project: $($projectFile.FullName)")
}

if ($LASTEXITCODE -eq 0) {
    Write-Information "Build succeeded for project: $($projectFile.FullName)"
}