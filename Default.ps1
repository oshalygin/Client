Properties {
    $sourceCodeHome = $psake.build_script_dir
    $defaultSolutionTarget = 'Build'
    $defaultSolutionConfiguration = 'debug'
    $nuget = 'c:\Tools\nuget.exe'
    $nunit = 'C:\Program Files (x86)\NUnit 2.6.4\bin\nunit-console.exe'
    $dotCoverFile = 'dotCover.exe'
    $dotCoverPath = (Join-Path $env:LOCALAPPDATA 'JetBrains\Installations\dotCover04')
    $coverageThreshold = 0
    $coverageReportPath = $psake.build_script_dir
    $csharpCoverageReport = 'administrationClient_csharp_coverage'
    $teamCityCoverageTool = 'dotcover'
    $version = "1.0.0.0"
    $dbMigrationPath = 'C:\git\Databases\Migration'
}

Framework '4.5.1x64'

FormatTaskName {
    param ($taskName)
    Write-Host "Executing Task: $taskName" -ForegroundColor Green -BackgroundColor Blue
}

Include (Join-Path $PSScriptRoot BuildHelpers.ps1)

Task Default -depends BuildClient

Task BuildClient -depends BuildAdministrationClient #, CodeCoverageAdministrationClient, AnalyzeCodeCoverageAdministrationClient
{
}

Task RestorePackagesAdministrationClient {
    Invoke-NuGetRestore -solutionPath (Join-Path $sourceCodeHome 'AdministrationClient.sln')
}

Task RestorePackagesAcceptanceTest {
    Invoke-NuGetRestore -solutionPath (Join-Path $sourceCodeHome 'Acceptance.Test.sln')
}


Task BuildAdministrationClient -depends RestorePackagesAdministrationClient {
    Invoke-MSBuild `
        $sourceCodeHome `
        'AdministrationClient.sln' `
        $defaultSolutionTarget `
        $defaultSolutionConfiguration `
        $version
}

Task CodeCoverageAdministrationClient {
    $dotCover = (Join-Path $dotCoverPath $dotCoverFile)
    $testFoldersPath = (Join-Path $psake.build_script_dir 'Test')

    $coverageReportSnapshotName = "{0}.dcvr" -f $csharpCoverageReport
    $coverageReportSnapshot = (Join-Path $coverageReportPath $coverageReportSnapshotName)
    if (Test-Path $coverageReportSnapshot){
        Remove-Item $coverageReportSnapshot
    }

    $coverageReportFileName = "{0}.xml" -f $csharpCoverageReport
    $coverageReportFile = (Join-Path $coverageReportPath $coverageReportFileName)
    if (Test-Path $coverageReportFile){
        Remove-Item $coverageReportFile
    }

    $testResultXml = (Join-Path $coverageReportPath "TestResult.xml")
    if (Test-Path $testResultXml) {
        Remove-Item $testResultXml
    }

    [string[]] $modules = "AH.AdministrationClient.Web.Test",
                          "AH.AdministrationClient.Api.Test"


    $coverageFilter = "-:AH.*.Api.Test;" +
                       "-:AH.*.Web.Test;"

    $coverageAttributeFilter = "System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"

    Invoke-DotCover `
        $dotCover `
        $testFoldersPath `
        $modules `
        $defaultSolutionConfiguration `
        $psake.build_script_dir `
        "AdministrationClient" `
        $coverageReportPath `
        $coverageReportSnapshot `
        $coverageReportFile `
        $coverageFilter `
        $coverageAttributeFilter
}

Task AnalyzeCodeCoverageAdministrationClient {
    $coverageReportFileName = "{0}.xml" -f $csharpCoverageReport
    $coverageReportFile = (Join-Path $coverageReportPath $coverageReportFileName)
    [xml]$coverageReport = Get-Content $coverageReportFile
    [int]$totalCoverage = $coverageReport.Root.CoveragePercent

    Write-Host "Total coverage: $totalCoverage"
    if ($totalCoverage -lt $coverageThreshold) {
        throw "Total coverage percent is less than the threshold! Coverage: $totalCoverage , Expected:$coverageThreshold"
    }
}

Task TeamCityCodeCoverageAdministrationClient -depends CodeCoverageAdministrationClient {
    $coverageReportSnapshotName = "{0}.dcvr" -f $csharpCoverageReport
    TeamCity-ImportDotNetCoverageResult `
        $teamCityCoverageTool `
        (Join-Path $coverageReportPath $coverageReportSnapshotName)
}
