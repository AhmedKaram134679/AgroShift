# verification_runner_helpers.ps1
# Reusable helper functions for AgroShift verification scripts.
#
# This file MUST NOT execute verification stages, invoke Flutter, launch child
# processes, or write run summaries when dot-sourced.

function Assert-ValidTestFilenames {
    param([string]$Root)
    $testDir = Join-Path $Root "test"
    if (-not (Test-Path -LiteralPath $testDir)) { return }
    $offendingFiles = @(Get-ChildItem -Path $testDir -Recurse -File -Filter "*_tests.dart")
    if ($offendingFiles.Count -gt 0) {
        $relPaths = $offendingFiles | ForEach-Object {
            $_.FullName.Substring($Root.Length).TrimStart('\', '/')
        }
        $msg = "NON_STANDARD_TEST_FILENAME_ERROR: Test files under test/ must not end with '_tests.dart' (violates automatic test discovery):`n" + ($relPaths -join "`n")
        Write-Error $msg
        throw $msg
    }
}
