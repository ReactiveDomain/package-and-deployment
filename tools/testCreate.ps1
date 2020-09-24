# CreateNuget.ps1
#
# This script will get the fileversion of ReactiveDomain.Core.dll. 
# This version number will be used to create the corresponding ReactiveDomain nuget packages 
# The ReactiveDomain nugets are then pushed to nuget.org
# 
# Note: If build is unstable, a beta (pre release) version of the nuget will be pushed
#       If build is stable, a stable (release) version will be pushed
# branch must be master to create a nuget
$configuration = "Release"
$nuspecExtension = ".nuspec"
$masterString = "master"
$branch = $env:TRAVIS_BRANCH
$apikey = $env:NugetOrgApiKey

# This changes when its a CI build or a manually triggered via the web UI
# api --> means manual/stable build ;  push --> means CI/unstable build
# pull_request --> CI build triggered when opening a PR (do nothing here)
$buildType = $env:TRAVIS_EVENT_TYPE 

Write-Host ("*********************   Begin Create NUget script   **************************************")   

Write-Host ("Build type is: " + $buildType)

Write-Host ("Powershell script location is " + $PSScriptRoot)