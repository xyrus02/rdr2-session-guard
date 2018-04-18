param(
    [Parameter(Mandatory = $true)] $Project,
    [Parameter(Mandatory = $true)] $Target,
    [Parameter(Mandatory = $true)] $Configuration
)

$buildTools = $global:System.Environment.BuildToolsPath

if ([string]::IsNullOrWhiteSpace($buildTools)) {
    throw("The environment variable ""BuildToolsPath"" was not set. Please use the file ""config.json"" in the repository root to provide the variable for the loaded environment ""$(env)"".")
}

$msbuildExecutable = Join-Path $buildTools "msbuild.exe"
$msbuildCommandLine = "/v:minimal /nologo /consoleloggerparameters:""NoSummary;ForceNoAlign"" /t:""$Target"" "

if (-not (Test-Path $msbuildExecutable -PathType Leaf)) {
    throw("MSBuild was not found at the provided build tools path: $($buildTools)")
}

$elr = [regex]::new("^(?:.*?)(?:\(\d+,\d+\))?:\s+error\s+(?:[A-Z]+\d+)?:\s(.*?)$", "IgnoreCase")
$wlr = [regex]::new("^(?:.*?)(?:\(\d+,\d+\))?:\s+warning\s+(?:[A-Z]+\d+)?:\s(.*?)$", "IgnoreCase")

[IO.FileInfo] $projectFile = $Project

Write-Information "Starting MSBuild for project: $($projectFile.FullName)"

$Configuration | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" } | Select-Object -ExpandProperty Name | Foreach-Object {
    $msbuildCommandLine = "$msbuildCommandLine/p:$_=""$($Configuration.$_)"" "
}

$msbuildCommandLine = "$msbuildCommandLine""$($projectFile.FullName)"""

Write-Verbose "MSBuild executable: $msbuildExecutable"
Write-Verbose "MSBuild command line: $msbuildCommandLine"

$errorCount = 0
"&""$msbuildExecutable"" $msbuildCommandLine" | Invoke-Expression | Foreach-Object {

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
    throw("MSBuild failed with exit code $LASTEXITCODE for project: $($projectFile.FullName)")
}

if ($LASTEXITCODE -eq 0) {
    Write-Information "MSBuild succeeded for project: $($projectFile.FullName)"
}