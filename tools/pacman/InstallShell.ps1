if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw ("An older version of PowerShell is used ($($PSVersionTable.PSVersion.ToString())). At least PowerShell 5 is required to run PACMAN.")
}

$Branch = "master"

# Bugfix 20180311_FailedCreateTlsSslSecuredChannel
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

[IO.DirectoryInfo] $TargetDirectory = (Get-Location).Path
[IO.DirectoryInfo] $TempDirectory = Join-Path "$env:LOCALAPPDATA" "XyrusWorx\Pacman\Setup\$((get-date).Ticks.ToString("X"))"
[IO.DirectoryInfo] $TargetPacmanDirectory = Join-Path $TargetDirectory.FullName "tools\pacman"

$ZipFile = Join-Path $TempDirectory.FullName "pacman-$Branch.zip"
$LicenseText = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/xyrus02/pacman/$Branch/LICENSE" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty "Content"

write-host -ForegroundColor cyan -NoNewline "PACMAN"
write-host -ForegroundColor white " Developer Shell"
write-host -ForegroundColor white "Copyright (c) XyrusWorx. All rights reserved."

if (-not [string]::IsNullOrWhiteSpace($LicenseText)) {
    write-host -ForegroundColor Gray "`n$($LicenseText.Trim(@("`r", "`n")))"
}

write-host ""

$ErrorActionPreference = "Stop"

if (Test-Path -Path $TempDirectory.FullName -PathType Container) { 
    Remove-Item -Force -Path $TempDirectory.FullName -Recurse 
}

try {
    Write-Host "Downloading archive..." -NoNewline
    $null = New-Item $TempDirectory.FullName -Force -ItemType Directory
    $null = Invoke-WebRequest -Uri "https://github.com/xyrus02/pacman/archive/$Branch.zip" -UseBasicParsing -OutFile $ZipFile
    Write-Host "OK" -ForegroundColor Green

    Write-Host "Extracting archive..." -NoNewline
    $null = Expand-Archive -Path $ZipFile -DestinationPath $TempDirectory.FullName
    Write-Host "OK" -ForegroundColor Green

    if (Test-Path -Path $TargetPacmanDirectory.FullName -PathType Container) { 
        Write-Host "Clearing previous installation..." -NoNewline
        Remove-Item -Force -Path $TargetPacmanDirectory.FullName -Recurse 
        Write-Host "OK" -ForegroundColor Green
    }
    
    Write-Host "Deploying to target..." -NoNewline
    $protectedFiles = @(
        Get-ChildItem -Path $TargetDirectory -Recurse -File | `
            Where-Object { -not $_.DirectoryName -eq $TargetDirectory.FullName }
    )

    $excludedFiles = @(
        @("README.md", "LICENSE", ".git*", "module-src") | Foreach-Object { Get-ChildItem -Path (Join-Path $TempDirectory.FullName "pacman-$Branch") -Filter $_ }
    )
    
    Get-ChildItem -Path (Join-Path $TempDirectory.FullName "pacman-$Branch") -Exclude $excludedFiles | `
        Copy-Item -Destination $TargetDirectory -Exclude $protectedFiles -Force -Recurse

    Write-Host "OK" -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    if (Test-Path -Path $TempDirectory.FullName -PathType Container) { 
        Write-Host "Cleaning up..." -NoNewline
        Remove-Item -Force -Path $TempDirectory.FullName -Recurse 
        Write-Host "OK" -ForegroundColor Green
    }
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
