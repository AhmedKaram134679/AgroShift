param(
    [string]$RepoRoot = $null,
    [string]$OutputDir = $null,
    [switch]$RequireCleanRevision = $false
)
$ErrorActionPreference = "Stop"

$runStartUtc = (Get-Date).ToUniversalTime()
$timestamp = $runStartUtc.ToString("yyyyMMdd_HHmmss")
$resolvedRepoRoot = if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
} else {
    [System.IO.Path]::GetFullPath($RepoRoot)
}

$evidenceDir = if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    Join-Path $resolvedRepoRoot "artifacts/validation_runs/$timestamp"
} else {
    [System.IO.Path]::GetFullPath($OutputDir)
}
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null

# Safely capture initial Git provenance before running any stage
$initialBranch = "unknown"
$initialCommit = "unknown"
$initialShortCommit = "unknown"
$initialWorkingTreeStatus = @()
$isInitiallyClean = $false

try {
    $initialBranch = (git -C $resolvedRepoRoot rev-parse --abbrev-ref HEAD 2>$null).Trim()
    $initialCommit = (git -C $resolvedRepoRoot rev-parse HEAD 2>$null).Trim()
    $initialShortCommit = (git -C $resolvedRepoRoot rev-parse --short HEAD 2>$null).Trim()
    $initialWorkingTreeStatus = @(git -C $resolvedRepoRoot status --porcelain 2>$null)
    $isInitiallyClean = ($initialWorkingTreeStatus.Count -eq 0)
} catch {
    # Non-fatal if executed in a synthetic non-git directory for tests
}

function Get-SourceTreeFingerprint {
    param([string]$Root)
    try {
        $sourcePaths = @("lib", "test", "scripts", "docs", "pubspec.yaml", "pubspec.lock")

        # 1. Enumerate tracked files within monitored scope
        $trackedFiles = @(git -C $Root ls-files -- @sourcePaths 2>$null)

        # 2. Enumerate untracked, non-ignored files within monitored scope
        $untrackedFiles = @(git -C $Root ls-files --others --exclude-standard -- @sourcePaths 2>$null)

        # Merge and sort unique normalized relative paths (using forward slashes)
        $allRelativePaths = @($trackedFiles + $untrackedFiles | Sort-Object -Unique)

        $sha = [System.Security.Cryptography.SHA256]::Create()
        $manifestLines = [System.Collections.Generic.List[string]]::new()
        $fileHashes = [System.Collections.Generic.Dictionary[string, string]]::new()

        foreach ($relPath in $allRelativePaths) {
            $normalizedPath = $relPath.Replace("\", "/").Trim()
            if ([string]::IsNullOrWhiteSpace($normalizedPath)) { continue }

            # Explicitly exclude generated verification run artifacts if ever located under monitored scope
            if ($normalizedPath.StartsWith("artifacts/") -or $normalizedPath -eq "artifacts") {
                continue
            }

            $fullPath = Join-Path $Root $normalizedPath
            if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
                # File listed by git but missing on filesystem during snapshot -> failure to establish authoritative inventory
                return [PSCustomObject]@{
                    Fingerprint = "unknown"
                    FileCount = 0
                    Files = @{}
                    Error = "File missing or inaccessible: $normalizedPath"
                }
            }

            try {
                $fileBytes = [System.IO.File]::ReadAllBytes($fullPath)
                $fileHashBytes = $sha.ComputeHash($fileBytes)
                $fileHashHex = -join ($fileHashBytes | ForEach-Object { $_.ToString("x2") })
                $manifestLines.Add("${normalizedPath}:${fileHashHex}")
                $fileHashes[$normalizedPath] = $fileHashHex
            } catch {
                return [PSCustomObject]@{
                    Fingerprint = "unknown"
                    FileCount = 0
                    Files = @{}
                    Error = "Failed to hash ${normalizedPath}: $($_.Exception.Message)"
                }
            }
        }

        # Deterministic composite fingerprint over sorted "path:sha256" lines
        $compositeManifest = $manifestLines -join "`n"
        $compositeBytes = [System.Text.Encoding]::UTF8.GetBytes($compositeManifest)
        $compositeHashBytes = $sha.ComputeHash($compositeBytes)
        $compositeHex = -join ($compositeHashBytes | ForEach-Object { $_.ToString("x2") })

        return [PSCustomObject]@{
            Fingerprint = $compositeHex
            FileCount = $manifestLines.Count
            Files = $fileHashes
            Error = $null
        }
    } catch {
        return [PSCustomObject]@{
            Fingerprint = "unknown"
            FileCount = 0
            Files = @{}
            Error = $_.Exception.Message
        }
    }
}

$initialSourceTreeObj = Get-SourceTreeFingerprint -Root $resolvedRepoRoot
$initialSourceFingerprint = $initialSourceTreeObj.Fingerprint

if ($RequireCleanRevision -and -not $isInitiallyClean) {
    Write-Error "Working tree is dirty and -RequireCleanRevision was specified. Refusing to run."
    exit 1
}

function Run-Stage {
    param(
        [string]$StageName,
        [string]$Command,
        [string]$OutPrefix
    )
    $stageStartUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Write-Host "Executing Stage: $StageName ($Command)..."
    $stdoutFile = Join-Path $evidenceDir "$OutPrefix.stdout.txt"
    $stderrFile = Join-Path $evidenceDir "$OutPrefix.stderr.txt"
    $exitCodeFile = Join-Path $evidenceDir "$OutPrefix.exitcode.txt"

    $tempStageScript = Join-Path $evidenceDir "$OutPrefix.cmd.ps1"
    $scriptBody = @"
try {
    `$ErrorActionPreference = 'Stop'
    $Command
    if (`$LASTEXITCODE -ne `$null -and `$LASTEXITCODE -ne 0) {
        exit `$LASTEXITCODE
    }
    exit 0
} catch {
    [Console]::Error.WriteLine(`$_.Exception.ToString())
    exit 1
}
"@
    [System.IO.File]::WriteAllText($tempStageScript, $scriptBody, [System.Text.Encoding]::UTF8)

    $stdout = ""
    $stderr = ""
    $code = $null
    $launchError = $null
    $outputError = $null
    $waitError = $null
    $evidenceWriteError = $null

    $p = $null
    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $executable = if ($env:AGROSHIFT_TEST_FAIL_STAGE -and $env:AGROSHIFT_TEST_FAIL_STAGE -eq $StageName) {
            "non_existent_process_executable_binary_12345.exe"
        } else {
            "powershell.exe"
        }
        $pinfo.FileName = $executable
        $pinfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$tempStageScript`""
        $pinfo.WorkingDirectory = $resolvedRepoRoot
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true

        $p = [System.Diagnostics.Process]::Start($pinfo)
        if ($null -eq $p) {
            throw "System.Diagnostics.Process.Start returned null."
        }
    } catch {
        $launchError = $_.Exception.ToString()
        $stderr = "PROCESS_LAUNCH_FAILURE: $launchError"
        # Documented failure code -1 indicates execution launch failure rather than child process exit
        $code = -1
    }

    if ($null -ne $p -and $null -eq $launchError) {
        # Read output streams asynchronously to avoid pipe buffer deadlocks
        $stdoutTask = $p.StandardOutput.ReadToEndAsync()
        $stderrTask = $p.StandardError.ReadToEndAsync()

        try {
            $p.WaitForExit()
            $code = $p.ExitCode
        } catch {
            $waitError = $_.Exception.ToString()
            if ($null -eq $code) {
                $code = 1
            }
        }

        try {
            [System.Threading.Tasks.Task]::WaitAll(@($stdoutTask, $stderrTask))
            $stdout = $stdoutTask.Result
            $stderr = $stderrTask.Result
        } catch {
            $outputError = $_.Exception.ToString()
            $stderr = if ([string]::IsNullOrWhiteSpace($stderr)) {
                "OUTPUT_COLLECTION_FAILURE: $outputError"
            } else {
                "$stderr`nOUTPUT_COLLECTION_FAILURE: $outputError"
            }
            if ($null -eq $code -or $code -eq 0) {
                $code = 1
            }
        }

        if ($null -ne $waitError) {
            $stderr = if ([string]::IsNullOrWhiteSpace($stderr)) {
                "PROCESS_WAIT_FAILURE: $waitError"
            } else {
                "$stderr`nPROCESS_WAIT_FAILURE: $waitError"
            }
        }
    }

    $stageEndUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    try {
        [System.IO.File]::WriteAllText($stdoutFile, $stdout, [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($stderrFile, $stderr, [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($exitCodeFile, "$code", [System.Text.Encoding]::UTF8)
    } catch {
        $evidenceWriteError = $_.Exception.ToString()
        if ($null -eq $code -or $code -eq 0) {
            $code = 1
        }
    }

    Write-Host "Stage $StageName completed with exit code: $code"
    return @{
        Stage = $StageName
        Command = $Command
        StartedAtUtc = $stageStartUtc
        CompletedAtUtc = $stageEndUtc
        ExitCode = $code
        Status = $(if ($code -eq 0) { "PASS" } else { "FAIL" })
        StdoutPath = $stdoutFile
        StderrPath = $stderrFile
        ExitCodePath = $exitCodeFile
        LaunchError = $launchError
        OutputError = $outputError
        WaitError = $waitError
        EvidenceWriteError = $evidenceWriteError
    }
}

# --- BEGIN VERIFICATION STAGES ---
$summary = [System.Collections.Generic.List[hashtable]]::new()
$summary.Add((Run-Stage -StageName "Dart Format" -Command "dart format --output=none --set-exit-if-changed lib/ test/" -OutPrefix "dart_format"))
$summary.Add((Run-Stage -StageName "Flutter Analyze" -Command "flutter analyze" -OutPrefix "flutter_analyze"))
$summary.Add((Run-Stage -StageName "Flutter Tests" -Command "flutter test" -OutPrefix "flutter_test"))
$summary.Add((Run-Stage -StageName "PowerShell Tests" -Command "powershell.exe -NoProfile -ExecutionPolicy Bypass -File test/scripts/test_validate_historical_models.ps1" -OutPrefix "powershell_tests"))
$summary.Add((Run-Stage -StageName "Release Build" -Command "flutter build apk --release" -OutPrefix "release_build"))
# --- END VERIFICATION STAGES ---

$runEndUtc = (Get-Date).ToUniversalTime()

# Capture ending Git provenance
$finalBranch = "unknown"
$finalCommit = "unknown"
$finalShortCommit = "unknown"
$finalWorkingTreeStatus = @()
$isFinallyClean = $false

try {
    $finalBranch = (git -C $resolvedRepoRoot rev-parse --abbrev-ref HEAD 2>$null).Trim()
    $finalCommit = (git -C $resolvedRepoRoot rev-parse HEAD 2>$null).Trim()
    $finalShortCommit = (git -C $resolvedRepoRoot rev-parse --short HEAD 2>$null).Trim()
    $finalWorkingTreeStatus = @(git -C $resolvedRepoRoot status --porcelain 2>$null)
    $isFinallyClean = ($finalWorkingTreeStatus.Count -eq 0)
} catch {
    # Non-fatal in synthetic test environments
}

$finalSourceTreeObj = Get-SourceTreeFingerprint -Root $resolvedRepoRoot
$finalSourceFingerprint = $finalSourceTreeObj.Fingerprint
$sourceMutated = ($initialCommit -ne $finalCommit) -or ($initialSourceFingerprint -ne "unknown" -and $initialSourceFingerprint -ne $finalSourceFingerprint)
$fingerprintError = if ($initialSourceTreeObj.Error) { $initialSourceTreeObj.Error } elseif ($finalSourceTreeObj.Error) { $finalSourceTreeObj.Error } else { $null }

$failedStages = @($summary | Where-Object { $_.ExitCode -ne 0 })
$overallStatus = if ($failedStages.Count -eq 0 -and $null -eq $fingerprintError) { "PASS" } else { "FAIL" }

$summaryObj = [PSCustomObject]@{
    RunStartUtc = $runStartUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    RunEndUtc = $runEndUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    DurationSeconds = [math]::Round(($runEndUtc - $runStartUtc).TotalSeconds, 2)
    Provenance = [PSCustomObject]@{
        Branch = $initialBranch
        StartingHeadCommit = $initialCommit
        StartingHeadShort = $initialShortCommit
        EndingHeadCommit = $finalCommit
        EndingHeadShort = $finalShortCommit
        IsStartingWorkingTreeClean = $isInitiallyClean
        StartingWorkingTreeEntries = $initialWorkingTreeStatus
        IsEndingWorkingTreeClean = $isFinallyClean
        EndingWorkingTreeEntries = $finalWorkingTreeStatus
        MonitoredSourceScope = @("lib", "test", "scripts", "docs", "pubspec.yaml", "pubspec.lock")
        InitialSourceFileCount = $initialSourceTreeObj.FileCount
        FinalSourceFileCount = $finalSourceTreeObj.FileCount
        InitialSourceTreeFingerprint = $initialSourceFingerprint
        FinalSourceTreeFingerprint = $finalSourceFingerprint
        FingerprintError = $fingerprintError
        SourceTreeMutatedDuringRun = $sourceMutated
        ValidationScope = if ($isInitiallyClean) { "Clean Committed Revision ($initialCommit)" } else { "Modified Working Tree over ($initialCommit)" }
    }
    OverallStatus = $overallStatus
    EvidenceDirectory = $evidenceDir
    Stages = $summary
    DeferredItems = @(
        @{ Name = "Physical Android Database Migration"; Status = "DEFERRED - NO PHYSICAL ANDROID DEVICE CONNECTED" }
    )
}

$summaryJson = $summaryObj | ConvertTo-Json -Depth 6
$summaryPath = Join-Path $evidenceDir "verification_summary.json"
$summaryPersistenceError = $null
try {
    [System.IO.File]::WriteAllText($summaryPath, $summaryJson, [System.Text.Encoding]::UTF8)
} catch {
    $summaryPersistenceError = $_.Exception.ToString()
    Write-Host "CRITICAL ERROR: Failed to persist verification summary to disk: $summaryPersistenceError" -ForegroundColor Red
}

Write-Host "All verification stages and logs recorded in: $evidenceDir"
Write-Host $summaryJson

if ($failedStages.Count -gt 0 -or $null -ne $fingerprintError -or $null -ne $summaryPersistenceError) {
    Write-Host "`nERROR: Verification failed (Failed stages: $($failedStages.Count), FingerprintError: $fingerprintError, SummaryPersistenceError: $summaryPersistenceError). Exit code 1." -ForegroundColor Red
    exit 1
}

Write-Host "`nSUCCESS: All verification stages passed. Exit code 0." -ForegroundColor Green
exit 0
