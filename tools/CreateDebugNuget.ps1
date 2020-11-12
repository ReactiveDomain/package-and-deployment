# CreateDebugNuget.ps1
#
# This script will use the local reactive-domain repo
# To create local debug reactive-domain nugets
# reactive-domain debug build should be done before running this script
# It will copy the debug nuspec files and the bld directory from the reactive-doain repo
# to a temp directory. From There it will pack the nugets 
# The resulting .nupkg files will be in the tools dir of the package-and-deployment repo

# args[0]: - the path to the reactive-domain repo
#           Note: If no valid path is passed in the script will ask for a valid path


$configuration = "Release"
$nuspecExtension = ".nuspec"
$masterString = "master"
$ReactiveDomainRepo = ""

if ($args[0] -eq $null )
{
	$ReactiveDomainRepo = Read-Host -Prompt 'Input valid path to reactiveDomain repo'
}
else
{
	if (Test-Path -Path $args[0])
	{
		$ReactiveDomainRepo = $args[0]
	}
	else
	{
		$ReactiveDomainRepo = Read-Host -Prompt 'Input valid path to reactiveDomain repo'
	}
}

Write-Host ("*********************   Begin Create Nuget script   **************************************")  

Write-Host ("Copy ReactiveDomain build folder and nuspec files to a temp directory")

$TempNum = Get-Random -Minimum 100 -Maximum 1000
$TempDir = Join-Path $env:temp $TempNum.ToString()
$buildDir = Join-Path $ReactiveDomainRepo "bld"
$sourceDir = Join-Path $ReactiveDomainRepo "src"
$tempBuildDir = Join-Path $TempDir "bld"
$tempSourceDir = Join-Path $TempDir "src"
New-Item -ItemType "directory" -Path $tempSourceDir
Copy-Item -Path $buildDir -Destination $tempBuildDir -Recurse

$sourceRDNuspec = Join-Path $sourceDir "ReactiveDomain.Debug.nuspec"
$sourceRDTestNuspec = Join-Path $sourceDir "ReactiveDomain.Testing.Debug.nuspec"
$sourceRDUINuspec = Join-Path $sourceDir "ReactiveDomain.UI.Debug.nuspec"
$sourceRDUITestNuspec = Join-Path $sourceDir "ReactiveDomain.UI.Testing.Debug.nuspec"

$ReactiveDomainNuspec = Join-Path $tempSourceDir "ReactiveDomain.Debug.nuspec"
$ReactiveDomainTestingNuspec = Join-Path $tempSourceDir "ReactiveDomain.Testing.Debug.nuspec"
$ReactiveDomainUINuspec = Join-Path $tempSourceDir "ReactiveDomain.UI.Debug.nuspec"
$ReactiveDomainUITestingNuspec = Join-Path $tempSourceDir "ReactiveDomain.UI.Testing.Debug.nuspec"

Copy-Item $sourceRDNuspec -Destination $ReactiveDomainNuspec
Copy-Item $sourceRDTestNuspec -Destination $ReactiveDomainTestingNuspec
Copy-Item $sourceRDUINuspec -Destination $ReactiveDomainUINuspec
Copy-Item $sourceRDUITestNuspec -Destination $ReactiveDomainUITestingNuspec

Write-Host ("Powershell script location is " + $PSScriptRoot)

$RDMajor = Get-Random -Maximum 100
$RDMinor = Get-Random -Maximum 100
$RDRevision = Get-Random -Maximum 100
$RDVersion = $RDMajor.ToString() + "."+ $RDMinor.ToString() + "." + $RDRevision.ToString()

$RDFoundationProject = $ReactiveDomainRepo + "\src\ReactiveDomain.Foundation\ReactiveDomain.Foundation.csproj"
$RDMessagingProject = $ReactiveDomainRepo + "\src\ReactiveDomain.Messaging\ReactiveDomain.Messaging.csproj"
$RDPersistenceProject = $ReactiveDomainRepo + "\src\ReactiveDomain.Persistence\ReactiveDomain.Persistence.csproj"
$RDPrivateLedgerProject = $ReactiveDomainRepo + "\src\ReactiveDomain.PrivateLedger\ReactiveDomain.PrivateLedger.csproj"
$RDTransportProject = $ReactiveDomainRepo + "\src\ReactiveDomain.Transport\ReactiveDomain.Transport.csproj"

$ReactiveDomainTestingProject = $ReactiveDomainRepo + "\src\ReactiveDomain.Testing\ReactiveDomain.Testing.csproj"
$RDUIProject = $ReactiveDomainRepo + "\src\ReactiveDomain.UI\ReactiveDomain.UI.csproj"
$RDUITestingProject = $ReactiveDomainRepo + "\src\ReactiveDomain.UI.Testing\ReactiveDomain.UI.Testing.csproj"
$nuget = $ReactiveDomainRepo + "\src\.nuget\nuget.exe"

Write-Host ("Reactive Domain version is " + $RDVersion)
Write-Host ("Build type is " + $buildType)
Write-Host ("ReactiveDomain nuspec file is " + $ReactiveDomainNuspec)
Write-Host ("ReactiveDomain.Testing nuspec file is " + $ReactiveDomainTestingNuspec)
Write-Host ("ReactiveDomain.UI nuspec file is " + $ReactiveDomainUINuspec)
Write-Host ("ReactiveDomain.UI.Testing nuspec file is " + $ReactiveDomainUITestingNuspec)
Write-Host ("Branch is file is " + $branch)

class PackagRef
{
    [string]$Version
    [string]$ComparisonOperator
    [string]$Framework
}

# GetPackageRefFromProject
#
#     Helper function to get a specific PackageRef from a .csproj file
#     Parses and returns a PackagRef object (defined above) that contains:
#         Version - (version of the package)
#         ConditionOperator - (the equality operator for a framework, == or !=)
#         Framework - The framework this Packageref applies to: (net452, net472, netstandard2.0)
#
function GetPackageRefFromProject([string]$Id, [string]$CsProj, [string]$Framework)
{
    [xml]$xml = Get-Content -Path $CsProj -Encoding UTF8

    $Xpath = "//Project/ItemGroup/PackageReference[@Include='" + $Id + "']"
    $targetPackage = $xml | Select-XML -XPath $Xpath
    $currentCondition = ""
    $compOperator = ""
    $currentFramework = ""
    $currentVersion = ""

    # There may be duplicates of the same package when there are different versions
    # for different frameworks (i.e. ReactiveUI). Therefore if our search
    # returns more than one node, then we take the one that matches 
    # the Framework in its Condition

    if ($targetPackage.Node.Count -gt 1)
    {
        foreach ($tn in $targetPackage.Node)
        {
            if ($tn.Condition -match $Framework )
            {
                $currentCondition = $tn.Condition
                $currentVersion = $tn.Version
            }
        }
    }
    else
    {
        $currentCondition = $targetPackage.Node.Condition
        $currentVersion = $targetPackage.Node.Version
    }

    if ($currentCondition -match "==")
    {
        $compOperator = "=="
    }

    if ($currentCondition -match "!=")
    {
        $compOperator = "!="
    }

    if ($currentCondition -match "net452")
    {
        $currentFramework = "net452"
    }

    if ($currentCondition -match "net472")
    {
        $currentFramework = "net472"
    }

    if ($currentCondition -match "netstandard2.0")
    {
        $currentFramework = "netstandard2.0"
    }

    $myObj = New-Object -TypeName PackagRef 
    $myObj.Version = $currentVersion
    $myObj.ComparisonOperator = $compOperator 
    $myObj.Framework = $currentFramework
    
    return $myObj
}

# UpdateDependencyVersions
#
#    Helper function that updates all non-ReactiveDomain dependencies 
#    in a nuspec file. Loops through all dependencies listed in a 
#    nuspec file and gets the versions from its
#    entry in the corresponding .csproj file
#
function UpdateDependencyVersions([string]$Nuspec, [string]$CsProj)
{
    Write-Host "Updating dependency versions of: " $Nuspec

    [xml]$xml = Get-Content -Path $Nuspec -Encoding UTF8
    $dependencyNodes = $xml.package.metadata.dependencies.group.dependency


    $f452 = $xml | Select-XML -XPath "//package/metadata/dependencies/group[@targetFramework='.NETFramework4.5.2']"
    $framework452Nodes = $f452.Node.ChildNodes

    $f472 = $xml | Select-XML -XPath "//package/metadata/dependencies/group[@targetFramework='.NETFramework4.7.2']"
    $framework472Nodes = $f472.Node.ChildNodes

    $netstandard2 = $xml | Select-XML -XPath "//package/metadata/dependencies/group[@targetFramework='.NETStandard2.0']"
    $netstandard2Nodes = $netstandard2.Node.ChildNodes

    foreach($refnode in $framework452Nodes)
    {
        if ( $refnode.id -match "ReactiveDomain")
        {
            $refnode.version = $RDVersion
            continue
        }

        $pRef = GetPackageRefFromProject $refnode.id $CsProj "net452"
        if ((($pRef.ComparisonOperator -eq "" -or $pRef.Framework -eq "") -or 
            ($pRef.ComparisonOperator -eq "==" -and $pRef.Framework -eq "net452") -or 
            ($pRef.ComparisonOperator -eq "!=" -and $pRef.Framework -ne "net452")) -and
            ($pRef.version -ne ""))
        {
            $refnode.version = $pRef.Version
        }       
    }

    foreach($refnode in $framework472Nodes)
    {
        if ( $refnode.id -match "ReactiveDomain")
        {
            $refnode.version = $RDVersion
            continue
        }

        $pRef = GetPackageRefFromProject $refnode.id $CsProj "net472"
        if ((($pRef.ComparisonOperator -eq "" -or $pRef.Framework -eq "") -or 
            ($pRef.ComparisonOperator -eq "==" -and $pRef.Framework -eq "net472") -or 
            ($pRef.ComparisonOperator -eq "!=" -and $pRef.Framework -ne "net472")) -and
            ($pRef.version -ne ""))
        {
            $refnode.version = $pRef.Version
        }      
    }

    foreach($refnode in $netstandard2Nodes)
    {
        if ( $refnode.id -match "ReactiveDomain")
        {
            $refnode.version = $RDVersion
            continue
        }
        
        $pRef = GetPackageRefFromProject $refnode.id $CsProj "netstandard2.0"
        if ((($pRef.ComparisonOperator -eq "" -or $pRef.Framework -eq "") -or 
            ($pRef.ComparisonOperator -eq "==" -and $pRef.Framework -eq "netstandard2.0") -or 
            ($pRef.ComparisonOperator -eq "!=" -and $pRef.Framework -ne "netstandard2.0")) -and
            ($pRef.version -ne ""))
        { 
            $refnode.version = $pRef.Version
        }      
    }

    $xml.Save($Nuspec)
    Write-Host "Updated dependency versions of: $Nuspec"
}

# Update the dependency versions in the nuspec files ****************************************************

# These all go into updating the main ReactiveDomain.nuspec
UpdateDependencyVersions $ReactiveDomainNuspec $RDFoundationProject  
UpdateDependencyVersions $ReactiveDomainNuspec $RDMessagingProject  
UpdateDependencyVersions $ReactiveDomainNuspec $RDPersistenceProject 
UpdateDependencyVersions $ReactiveDomainNuspec $RDPrivateLedgerProject 
UpdateDependencyVersions $ReactiveDomainNuspec $RDTransportProject 

# These go into updating the ReactiveDomainUI.nuspec
UpdateDependencyVersions $ReactiveDomainUINuspec $RDUIProject 

# These go into updating the ReactiveDomainTesting.nuspec
UpdateDependencyVersions $ReactiveDomainTestingNuspec $ReactiveDomainTestingProject 

# These go into updating the ReactiveDomain.UI.Testing.nuspec
UpdateDependencyVersions $ReactiveDomainUITestingNuspec $RDUITestingProject 

# *******************************************************************************************************

# Pack the nuspec files to create the .nupkg files using the set versionString  *************************
Write-Host "Packing reactivedomain nuget packages"
Write-Host "Version string to use: " + $versionString
$versionString = $RDVersion
& $nuget pack $ReactiveDomainNuspec -Version $versionString
& $nuget pack $ReactiveDomainTestingNuspec -Version $versionString
& $nuget pack $ReactiveDomainUINuspec -Version $versionString
& $nuget pack $ReactiveDomainUITestingNuspec -Version $versionString

# *******************************************************************************************************************************

# Cleanup the temp directory
Remove-Item $TempDir -Recurse 