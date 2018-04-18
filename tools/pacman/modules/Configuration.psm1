function Join-Object {
    param(
        [Parameter(Mandatory = $true, Position = 0)] [object] $Left,
        [Parameter(Mandatory = $true, Position = 1)] [object] $Right)

    if ($Right -is [System.ValueType] -or $Right -is [System.String] -or $Left -is [System.ValueType] -or $Left -is [System.String]) {
        return $Right
    }

    $Result = ([PSCustomObject] $Left)
    $RightMembers = ([PSCustomObject] $Right) | Get-Member -MemberType NoteProperty

    foreach($currentMember in $RightMembers) {
        $currentName = $currentMember.Name

        $leftMember = [Microsoft.PowerShell.Commands.MemberDefinition] ($Result | Get-Member -MemberType NoteProperty -Name $currentName | Select-Object -First 1)
        $rightMember = [Microsoft.PowerShell.Commands.MemberDefinition] $currentMember

        if ($leftMember -eq $null) {
            $Result | Add-Member -MemberType NoteProperty -Name $rightMember.Name -Value ($Right."$currentName")
            continue
        }

        if ($leftMember.MemberType -eq "NoteProperty") {
            $compositeValue = Join-Object -Left ($Left."$currentName") -Right ($Right."$currentName")
            $Result | Add-Member -MemberType NoteProperty -Force -Name $leftMember.Name -Value $compositeValue
        }
    }

    return $Result
}

class PropertyContainer {

    hidden [string] $_Path
    hidden [object] $_ChildName
    hidden [PropertyContainer] $_Owner
    hidden [PSCustomObject] $_CachedModel

    PropertyContainer ([string] $Path) {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw("Path can't be empty")
        }

        $this._Path = [IO.Path]::GetFullPath($Path)
    }

    [object] getProperty([string] $Property) { 
        if ([string]::IsNullOrWhiteSpace($Property)) {
            throw("Property name can't be empty")
        }

        $node = $this.getObject()
        return $this.getChildOrValue($node, $Property)
    }
    [void] setProperty([string] $Property, [object] $Value) { 
        if ([string]::IsNullOrWhiteSpace($Property)) {
            throw("Property name can't be empty")
        }

        $node = $this.getObject()

        if ($Value -is [System.Collections.Hashtable]) {
            $Value = [PSCustomObject] $Value
        }

        $node | Add-Member -MemberType NoteProperty -Force -Name $Property -Value $Value
        $this.saveRootNode();
    }

    [PropertyContainer] getChild([string] $Child){
        if ([string]::IsNullOrWhiteSpace($Child)) {
            throw("Child name can't be empty")
        }

        return [PropertyContainer]::new($this, $Child)
    }
    [PSCustomObject] getObject() {
        return $this.readCurrentNode($false)
    }
    [string] getNodePath(){
        if ($this._Owner -ne $null) {
            return "$($this._Owner.getNodePath())/$($this._ChildName)"
        }
        return [string]::Empty
    }
    [string] getTargetPath() {
        if ([string]::IsNullOrWhiteSpace($this._Path)) {
            return $this._Owner.getTargetPath()
        }
        return $this._Path
    }

    [string] ToString() {
        return "$($this.getTargetPath()):/$($this.getNodePath().TrimStart("/"))"
    }

    hidden PropertyContainer ([PropertyContainer] $Owner, [string] $ChildName) {
        if ($Owner -eq $null) {
            throw("Owner can't be empty")
        }
        if ($ChildName -eq $null) {
            throw("Child name can't be empty")
        }

        $this._Owner = $Owner
        $this._ChildName = $ChildName
        $this._Path = $null
    }

    hidden [PSCustomObject] readCurrentNode([bool] $avoidReload) {
        if ([string]::IsNullOrWhiteSpace($this._Path)) {
            return $this._Owner.readChildNode($this._ChildName,$avoidReload)
        }

        if (-not (Test-Path $this._Path -PathType Leaf)) {
            if ($this._CachedModel -eq $null)
            {
                $this._CachedModel = $this.getNewNode()
            }
        }
        else {
            if (-not $avoidReload -or $this._CachedModel -eq $null) {
                $this._CachedModel = Get-Content -Raw $this._Path | ConvertFrom-Json
            }
        }

        return $this._CachedModel
    }
    hidden [PSCustomObject] readChildNode([string] $ChildName, [bool] $avoidReload) {

        $node = $this.readCurrentNode($avoidReload)
        $member = $node `
            | Get-Member -Type NoteProperty `
            | Where-Object { [string]::Equals($_.Name, "$ChildName".Trim(), "InvariantCultureIgnoreCase") } `
            | Select-Object -First 1 -ExpandProperty $_.Name

        if ($member -eq $null) {
            $node | Add-Member -Type NoteProperty -Name $ChildName -Value ($this.getNewNode())
            if (-not $avoidReload) {
                $this.saveRootNode();
                $node = $this.getObject()
            }
        }

        return $node."$ChildName"
    }
    
    hidden [PSCustomObject] getNewNode() {
        return [PSCustomObject] @{ }
    }
    hidden [object] getChildOrValue([object] $Node, [string] $Property) {

        if ($Node -eq $null) {
            $Node = $this.getNewNode()
        }

        $member = $Node `
            | Get-Member -Type NoteProperty `
            | Where-Object { [string]::Equals($_.Name, "$Property".Trim(), "InvariantCultureIgnoreCase") } `
            | Select-Object -First 1 -ExpandProperty $_.Name

        if ($member -eq $null) {
            return $null
        }

        return $Node | Select-Object -ExpandProperty $member.Name
    }
    hidden [void] saveRootNode() {

        if ($this._Owner -ne $null) {
            $this._Owner.saveRootNode()
        }
        else {
            $this.readCurrentNode($true) | ConvertTo-Json -Depth 100 | Set-Content $this._Path
        }
    }
}

class MergeContainer {

	hidden $_Metadata
	hidden [Array] $_Containers
	hidden [MergeContainer] $_Owner
	hidden [string] $_ChildName
	
	MergeContainer ([String] $OwnerId, [Array] $Containers) {
		$this._Containers = @($Containers)
		$this._Metadata = @{
			Package = "$OwnerId"
		}
	}
	hidden MergeContainer ([MergeContainer] $Owner, [string] $ChildName) {
		if ($Owner -eq $null) {
            throw("Owner can't be empty")
        }
        if ($ChildName -eq $null) {
            throw("Child name can't be empty")
        }

		$this._Owner = $Owner
		$this._ChildName = $ChildName
		$this._Metadata = $Owner._Metadata
		$this._Containers = @()
	}
	
	[object] getProperty([string] $Property) {
		if ([string]::IsNullOrWhiteSpace($Property)) {
            throw("Property name can't be empty")
		}
		
		if ($this._Owner -ne $null){
			$obj = [PSCustomObject]($this._Owner.getProperty($this._ChildName))
		} else {
			$obj = $this.getObject()
		}

		return $obj."$Property"
	}
	[MergeContainer] getChild([string] $Child){
        if ([string]::IsNullOrWhiteSpace($Child)) {
            throw("Child name can't be empty")
        }

        return [MergeContainer]::new($this, $Child)
    }
	[PSCustomObject] getObject() {
	
		if ($this._Owner -ne $null){
			return $this._Owner.getProperty($this._ChildName)
		} 

		$obj = [PSCustomObject] $this._Metadata
		
		for($i = $this._Containers.Length - 1; $i -ge 0 ; $i--) {
			$obj = Join-Object $obj ($this._Containers[$i].getObject())
		}

		return $obj
	}

	[string] getNodePath(){
        if ($this._Owner -ne $null) {
            return "$($this._Owner.getNodePath())/$($this._ChildName)"
        }
        return [string]::Empty
    }

	[String] ToString() {
		return "$(Split-Path -Leaf -Path ($this._Containers[0].getTargetPath())):/$($this.getNodePath().TrimStart("/"))"
	}
}
function New-PropertyContainer { 
    param([Parameter(Mandatory = $true, Position = 0)] [string] $Path, [switch] $Force)
    
    if ($Force -and -not (Test-Path $Path -PathType Leaf)){
        [IO.File]::WriteAllText($Path, "{`r`n}")
    }

	return New-Object PropertyContainer -ArgumentList @($Path) 
}

function New-MergeContainer { 
    param(
        [Parameter(Mandatory = $true, Position = 0)] [PropertyContainer[]] $Containers, 
        [Parameter(Mandatory = $false, Position = 1)] $PackageId
    )
    
   return New-Object "MergeContainer" -ArgumentList @($PackageId,@($Containers))
}

Export-ModuleMember -Function @(
    "New-PropertyContainer",
    "New-MergeContainer"
)