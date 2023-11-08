[CmdletBinding()]
Param(
    [Parameter(Position=1)]
    [String] $Target = "build",
    [String] $JenkinsVersion = '2.430',
    [switch] $DryRun = $false
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # Disable Progress bar for faster downloads

$Repository = 'jenkins'
$Organization = 'jenkins4eval'
$ImageType = 'windowsservercore-ltsc2019' # <WINDOWS_FLAVOR>-<WINDOWS_VERSION>

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_REPO)) {
    $Repository = $env:DOCKERHUB_REPO
}

if(![String]::IsNullOrWhiteSpace($env:DOCKERHUB_ORGANISATION)) {
    $Organization = $env:DOCKERHUB_ORGANISATION
}

if(![String]::IsNullOrWhiteSpace($env:JENKINS_VERSION)) {
    $JenkinsVersion = $env:JENKINS_VERSION
}

if(![String]::IsNullOrWhiteSpace($env:IMAGE_TYPE)) {
    $ImageType = $env:IMAGE_TYPE
}

$env:JENKINS_VERSION = "$JenkinsVersion"
$env:DOCKERHUB_ORGANISATION = "$Organization"
$env:DOCKERHUB_REPO = "$Repository"
Write-Host "= PREPARE: env:JENKINS_VERSION = $env:JENKINS_VERSION"

$items = $ImageType.Split("-")
$env:WINDOWS_FLAVOR = $items[0]
$env:WINDOWS_VERSION = $items[1]
$env:TOOLS_WINDOWS_VERSION = $items[1]
if ($items[1] -eq 'ltsc2019') {
    # There are no eclipse-temurin:*-ltsc2019 or mcr.microsoft.com/powershell:*-ltsc2019 docker images unfortunately, only "1809" ones
    $env:TOOLS_WINDOWS_VERSION = '1809'
}
Write-Host "= PREPARE: env:WINDOWS_FLAVOR = $env:WINDOWS_FLAVOR"
Write-Host "= PREPARE: env:WINDOWS_VERSION = $env:WINDOWS_VERSION"
Write-Host "= PREPARE: env:TOOLS_WINDOWS_VERSION = $env:TOOLS_WINDOWS_VERSION"

# Retrieve the sha256 corresponding to the JENKINS_VERSION
$jenkinsShaURL = 'https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/jenkins-war/{0}/jenkins-war-{0}.war.sha256' -f $env:JENKINS_VERSION
$webClient = New-Object System.Net.WebClient
$env:JENKINS_SHA = $webClient.DownloadString($jenkinsShaURL).ToUpper()
Write-Host "= PREPARE: env:JENKINS_SHA = $env:JENKINS_SHA"

$env:COMMIT_SHA=$(git rev-parse HEAD)
Write-Host "= PREPARE: env:COMMIT_SHA = $env:COMMIT_SHA"

$baseDockerCmd = 'docker-compose --file=build-windows.yaml'
$baseDockerBuildCmd = '{0} build --parallel --pull' -f $baseDockerCmd

Write-Host "= PREPARE: List of $Organization/$Repository images and additional tags to be processed:"
Invoke-Expression "$baseDockerCmd config"

Write-Host "= BUILD: Building all images..."
switch ($DryRun) {
    $true { Write-Host "(dry-run) $baseDockerBuildCmd" }
    $false { Invoke-Expression $baseDockerBuildCmd }
}
Write-Host "= BUILD: Finished building all images."

if($lastExitCode -ne 0 -and !$DryRun) {
    exit $lastExitCode
}

function Test-Image {
    param (
        $ImageName
    )

    Write-Host "= TEST: Testing image ${ImageName}:"

    $env:CONTROLLER_IMAGE = $ImageName
    $env:DOCKERFILE = 'windows/{0}/hotspot/Dockerfile' -f $env:WINDOWS_FLAVOR
    if (Test-Path ".\target\$ImageName") {
        Remove-Item -Recurse -Force ".\target\$ImageName"
    }
    New-Item -Path ".\target\$ImageName" -Type Directory | Out-Null
    $configuration.TestResult.OutputPath = ".\target\$ImageName\junit-results.xml"

    $TestResults = Invoke-Pester -Configuration $configuration
    if ($TestResults.FailedCount -gt 0) {
        Write-Host "There were $($TestResults.FailedCount) failed tests in $ImageName"
        $testFailed = $true
    } else {
        Write-Host "There were $($TestResults.PassedCount) passed tests out of $($TestResults.TotalCount) in $ImageName"
    }
    Remove-Item env:\CONTROLLER_IMAGE
    Remove-Item env:\DOCKERFILE
}

if($target -eq "test") {
    if ($DryRun) {
        Write-Host "(dry-run) test"
    } else {
        # Only fail the run afterwards in case of any test failures
        $testFailed = $false
        $mod = Get-InstalledModule -Name Pester -MinimumVersion 5.3.0 -MaximumVersion 5.3.3 -ErrorAction SilentlyContinue
        if($null -eq $mod) {
            $module = "c:\Program Files\WindowsPowerShell\Modules\Pester"
            if(Test-Path $module) {
                takeown /F $module /A /R
                icacls $module /reset
                icacls $module /grant Administrators:'F' /inheritance:d /T
                Remove-Item -Path $module -Recurse -Force -Confirm:$false
            }
            Install-Module -Force -Name Pester -Verbose -MaximumVersion 5.3.3
        }

        Import-Module -Verbose Pester
        Write-Host "= TEST: Setting up Pester environment..."
        $configuration = [PesterConfiguration]::Default
        $configuration.Run.PassThru = $true
        $configuration.Run.Path = '.\tests'
        $configuration.Run.Exit = $true
        $configuration.TestResult.Enabled = $true
        $configuration.TestResult.OutputFormat = 'JUnitXml'
        $configuration.Output.Verbosity = 'Diagnostic'
        $configuration.CodeCoverage.Enabled = $false

        Write-Host "= TEST: Testing all images..."
        $compose = Invoke-Expression "$baseDockerCmd config --format=json" 2>$null | ConvertFrom-Json
        foreach ($service in $compose.services.PSObject.Properties) {
            $imageParts = $service.Value.image -split ':'
            Test-Image $imageParts[1]
        }    

        # Fail if any test failures
        if($testFailed -ne $false) {
            Write-Error "Test stage failed!"
            exit 1
        } else {
            Write-Host "Test stage passed!"
        }
    }
}

if($target -eq "publish") {
    Write-Host "= PUBLISH: push all images and tags"
    switch($DryRun) {
        $true { Write-Host "(dry-run) $baseDockerCmd push" }
        $false { Invoke-Expression "$baseDockerCmd push" }
    }
    # Fail if any issues when publishing the docker images
    if($lastExitCode -ne 0) {
        Write-Error "= PUBLISH: failed!"
        exit 1
    }
}

if($lastExitCode -ne 0 -and !$DryRun) {
    Write-Error "Build failed!"
} else {
    Write-Host "Build finished successfully"
}
exit $lastExitCode
