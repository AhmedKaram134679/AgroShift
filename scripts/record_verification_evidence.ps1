param()
$ErrorActionPreference = "Stop"

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss")
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$evidenceDir = Join-Path $repoRoot "artifacts/validation_runs/$timestamp"
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null

function Run-Stage {
    param(
        [string]$StageName,
        [string]$Command,
        [string]$OutPrefix
    )
    Write-Host "Executing Stage: $StageName ($Command)..."
    $stdoutFile = Join-Path $evidenceDir "$OutPrefix.stdout.txt"
    $stderrFile = Join-Path $evidenceDir "$OutPrefix.stderr.txt"
    $exitCodeFile = Join-Path $evidenceDir "$OutPrefix.exitcode.txt"

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "powershell.exe"
    $pinfo.Arguments = "-NoProfile -Command $Command"
    $pinfo.WorkingDirectory = $repoRoot
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true

    $p = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $code = $p.ExitCode

    [System.IO.File]::WriteAllText($stdoutFile, $stdout, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($stderrFile, $stderr, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($exitCodeFile, "$code", [System.Text.Encoding]::UTF8)

    Write-Host "Stage $StageName completed with exit code: $code"
    return @{
        Stage = $StageName
        Command = $Command
        ExitCode = $code
        Status = $(if ($code -eq 0) { "PASS" } else { "FAIL" })
        StdoutPath = $stdoutFile
        StderrPath = $stderrFile
        ExitCodePath = $exitCodeFile
    }
}

$summary = [System.Collections.Generic.List[hashtable]]::new()
$summary.Add((Run-Stage -StageName "Dart Format" -Command "dart format --output=none --set-exit-if-changed lib/ test/" -OutPrefix "dart_format"))
$summary.Add((Run-Stage -StageName "Flutter Analyze" -Command "flutter analyze" -OutPrefix "flutter_analyze"))
$summary.Add((Run-Stage -StageName "Flutter Tests" -Command "flutter test" -OutPrefix "flutter_test"))
$summary.Add((Run-Stage -StageName "PowerShell Tests" -Command "powershell.exe -NoProfile -ExecutionPolicy Bypass -File test/scripts/test_validate_historical_models.ps1" -OutPrefix "powershell_tests"))
$summary.Add((Run-Stage -StageName "Release Build" -Command "flutter build apk --release" -OutPrefix "release_build"))

$commitHash = (git rev-parse HEAD).Trim()
$summaryObj = [PSCustomObject]@{
    RunTimestampUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    CommitHash = $commitHash
    EvidenceDirectory = $evidenceDir
    Stages = $summary
    DeferredItems = @(
        @{ Name = "Physical Android Database Migration"; Status = "DEFERRED - NO PHYSICAL ANDROID DEVICE CONNECTED" }
    )
}

$summaryJson = $summaryObj | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText((Join-Path $evidenceDir "verification_summary.json"), $summaryJson, [System.Text.Encoding]::UTF8)
Write-Host "All verification stages recorded in: $evidenceDir"
Write-Host $summaryJson
