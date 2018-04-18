Move-Item `
    -Path        (join-path $_.Package.Directory.FullName "project.csproj") `
    -Destination (join-path $_.Package.Directory.FullName "$($_.Metadata.getProperty("name")).csproj") 

$projectProperties = New-PropertyContainer (Join-Path $_.Package.Directory.FullName "package.json")
$projectProperties.setProperty("pacman", @{
    "build" = @{
        "projects" = "*.csproj"
        "target" = "Restore,Pack"
        "parameters" = @{
            "configuration" = "Release"
            "platform" = "Any CPU"
        }
    }
})