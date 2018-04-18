$CommonAttributes = New-Object "System.Collections.Generic.Dictionary[System.String,System.Type]"
$null = $CommonAttributes.Add("Culture",[System.String])
$null = $CommonAttributes.Add("Flags",[System.Reflection.AssemblyNameFlags])
$null = $CommonAttributes.Add("Version",[System.String])
$null = $CommonAttributes.Add("Company",[System.String])
$null = $CommonAttributes.Add("Copyright",[System.String])
$null = $CommonAttributes.Add("FileVersion",[System.String])
$null = $CommonAttributes.Add("InformationalVersion",[System.String])
$null = $CommonAttributes.Add("Product",[System.String])
$null = $CommonAttributes.Add("Trademark",[System.String])
$null = $CommonAttributes.Add("Configuration",[System.String])
$null = $CommonAttributes.Add("DefaultAlias",[System.String])
$null = $CommonAttributes.Add("Description",[System.String])
$null = $CommonAttributes.Add("Title",[System.String])
$null = $CommonAttributes.Add("DelaySign",[System.Boolean])
$null = $CommonAttributes.Add("KeyFile",[System.String])
$null = $CommonAttributes.Add("KeyName",[System.String])

function Get-AssemblyAttributes {
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $false)] [string] $InputString
    )
    begin {
        $regex = New-Object System.Text.RegularExpressions.Regex -ArgumentList @( `
            "\[\s*assembly\s*:\s*(?:Assembly)?(.*?)(?:Attribute)?\(\s*""?(.*?)""?(?:,.*?)*\s*\)\s*\]", `
            ([System.Text.RegularExpressions.RegexOptions]::Multiline -bor `
             [System.Text.RegularExpressions.RegexOptions]::CultureInvariant))
        $captured = New-Object System.Collections.Generic.HashSet[System.String]
    }
    process {
        if ([string]::IsNullOrWhiteSpace($InputString)) {
            return
        }

        $regex.Matches($InputString) | Foreach-Object {
            $match  = [System.Text.RegularExpressions.Match] $_
            $itmKey = $match.Groups[1].Value

            if ($captured.Add($itmKey)) {
                $result = New-Object PSObject

                Add-Member -InputObject $result -MemberType NoteProperty -Name "Name"   -Value ($match.Groups[1].Value)
                Add-Member -InputObject $result -MemberType NoteProperty -Name "Value"  -Value ($match.Groups[2].Value)
                Add-Member -InputObject $result -MemberType NoteProperty -Name "Offset" -Value ($match.Groups[2].Index)

                Write-Output $result
            }
        }
    }
}

function Get-AssemblyAttribute {
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]  [string] $InputString,
        [Parameter(ValueFromPipeline = $true, Position = 0, Mandatory = $true)]  [string] $Name
    )

    $attribute = $InputString | Get-AssemblyAttributes | Where-Object { $_.Name -eq $Name } | Select-Object -First 1

    if ($attribute -ne $null) { 
        return $attribute.Value 
    }

    return $null
}

function Set-AssemblyAttribute {
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $false)] [string] $InputString,
        [Parameter(ValueFromPipeline = $true, Mandatory = $false)] [switch] $Raw,

        [Parameter(ValueFromPipeline = $true, Position = 0, Mandatory = $true)]  [string] $Name,
        [Parameter(ValueFromPipeline = $true, Position = 1, Mandatory = $false)] $Value
    )

    $InputString = "$InputString"
    $attribute = $InputString | Get-AssemblyAttributes | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    $outputStringBuilder = New-Object System.Text.StringBuilder

    if ($attribute -ne $null) { 
        $oldValue = $attribute.Value

        if ([string]::IsNullOrEmpty($OldValue)) {
            $oldValue = [string]::Empty
        }

        $null = $outputStringBuilder.Append($InputString.Substring(0, $attribute.Offset))
        $null = $outputStringBuilder.Append($Value)
        $null = $outputStringBuilder.Append($InputString.Substring($attribute.Offset + $oldValue.Length));
    }
    else {
        
        $ExpandedName = $Name
        $TargetType = [System.Type]([System.String])
        $ValueType = [System.Type]([System.String])

        if ($Value -ne $null) {
            $ValueType = $Value.GetType()
        }
        
        if ($CommonAttributes.ContainsKey($Name)) {
            $ExpandedName = "Assembly$Name"
            $TargetType = $CommonAttributes[$Name]
        } 
        else {
            $TargetType = $ValueType
        }

        if ($TargetType -eq [System.String] -and -not $Raw) {
            $Value = """$Value"""
        }

        $null = $outputStringBuilder.Append($InputString)

        if (-not $InputString.EndsWith("`n") -and -not [string]::IsNullOrWhiteSpace($InputString)) {
            $null = $outputStringBuilder.Append([Environment]::NewLine)
        }

        $null = $outputStringBuilder.AppendFormat("[assembly: $ExpandedName($Value)]`r`n")
    }


    return $OutputStringBuilder.ToString()
}

Export-ModuleMember -Function @(
    "Get-AssemblyAttributes",
    "Get-AssemblyAttribute",
    "Set-AssemblyAttribute"
)