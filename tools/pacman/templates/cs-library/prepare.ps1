$_.Metadata.setProperty("name",        ($_.Properties.Name,        $_.Metadata.getProperty("name")        -ne $null)[0])
$_.Metadata.setProperty("description", ($_.Properties.Description, $_.Metadata.getProperty("description") -ne $null)[0])
$_.Metadata.setProperty("version",     ($_.Properties.Version,     $_.Metadata.getProperty("version")     -ne $null)[0])