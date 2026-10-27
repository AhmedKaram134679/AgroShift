# AgroShift - Deterministic Tests for validate_historical_models.ps1
# Covers:
# 1. Test-HistoricalApiResponse: PASS, INCOMPATIBLE (missing/null variable values), ERROR (structural issues)
# 2. Executable process testing: child powershell invocation verifying actual process exit codes ($LASTEXITCODE) and -FailOnAnyModelError contract

$ErrorActionPreference = "Stop"

$scriptPath = "$PSScriptRoot/../../scripts/validate_historical_models.ps1"
# Source function directly for unit testing
. $scriptPath

$expectedDates = @("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05")

function New-ValidFixture {
    return [PSCustomObject]@{
        latitude = 31.0
        longitude = 31.0
        elevation = 6.0
        daily_units = [PSCustomObject]@{
            time = "iso8601"
            temperature_2m_max = "$([char]0x00B0)C"
            temperature_2m_min = "$([char]0x00B0)C"
            et0_fao_evapotranspiration = "mm"
            precipitation_sum = "mm"
        }
        daily = [PSCustomObject]@{
            time = @("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05")
            temperature_2m_max = @(35.0, 36.2, 34.8, 37.0, 35.5)
            temperature_2m_min = @(20.0, 21.1, 20.5, 22.0, 21.0)
            et0_fao_evapotranspiration = @(6.5, 7.1, 6.8, 7.5, 6.9)
            precipitation_sum = @(0.0, 0.0, 0.0, 0.0, 0.0) # 0.0 is legitimate numeric reading
        }
    }
}

$testsRun = 0
$testsPassed = 0

function Assert-Result {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$Message = ""
    )
    $script:testsRun++
    if ($Condition) {
        $script:testsPassed++
        Write-Host " [PASS] $TestName" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] $TestName - $Message" -ForegroundColor Red
    }
}

Write-Host "================================================================="
Write-Host "Running Historical API Validator Unit Tests..." -ForegroundColor Cyan
Write-Host "================================================================="

# Test 1: Complete and valid response -> PASS
$validObj = New-ValidFixture
$res1 = Test-HistoricalApiResponse -Response $validObj -ExpectedDates $expectedDates
Assert-Result -TestName "All 4 variables valid and populated -> PASS" -Condition ($res1.Outcome -eq "PASS" -and $res1.IsValid -eq $true)

# Test 2: Missing Tmax value (null) -> INCOMPATIBLE
$nullTmaxObj = New-ValidFixture
$nullTmaxObj.daily.temperature_2m_max[2] = $null
$res2 = Test-HistoricalApiResponse -Response $nullTmaxObj -ExpectedDates $expectedDates
Assert-Result -TestName "Null Tmax observation -> INCOMPATIBLE" -Condition ($res2.Outcome -eq "INCOMPATIBLE" -and $res2.IsValid -eq $false -and $res2.Errors -match "temperature_2m_max.*null")

# Test 3: Missing Tmin value (null) -> INCOMPATIBLE
$nullTminObj = New-ValidFixture
$nullTminObj.daily.temperature_2m_min[1] = $null
$res3 = Test-HistoricalApiResponse -Response $nullTminObj -ExpectedDates $expectedDates
Assert-Result -TestName "Null Tmin observation -> INCOMPATIBLE" -Condition ($res3.Outcome -eq "INCOMPATIBLE" -and $res3.IsValid -eq $false -and $res3.Errors -match "temperature_2m_min.*null")

# Test 4: Missing ET0 value (null) -> INCOMPATIBLE
$nullEt0Obj = New-ValidFixture
$nullEt0Obj.daily.et0_fao_evapotranspiration[0] = $null
$res4 = Test-HistoricalApiResponse -Response $nullEt0Obj -ExpectedDates $expectedDates
Assert-Result -TestName "Null ET0 observation -> INCOMPATIBLE" -Condition ($res4.Outcome -eq "INCOMPATIBLE" -and $res4.IsValid -eq $false -and $res4.Errors -match "et0_fao_evapotranspiration.*null")

# Test 5: Missing Precipitation value (null) -> INCOMPATIBLE
$nullPrecipObj = New-ValidFixture
$nullPrecipObj.daily.precipitation_sum[4] = $null
$res5 = Test-HistoricalApiResponse -Response $nullPrecipObj -ExpectedDates $expectedDates
Assert-Result -TestName "Null Precipitation observation -> INCOMPATIBLE" -Condition ($res5.Outcome -eq "INCOMPATIBLE" -and $res5.IsValid -eq $false -and $res5.Errors -match "precipitation_sum.*null")

# Test 6: Missing mandatory variable array entirely -> INCOMPATIBLE
$missingArrObj = New-ValidFixture
$missingArrObj.daily.PSObject.Properties.Remove("et0_fao_evapotranspiration")
$res6 = Test-HistoricalApiResponse -Response $missingArrObj -ExpectedDates $expectedDates
Assert-Result -TestName "Missing variable array entirely -> INCOMPATIBLE" -Condition ($res6.Outcome -eq "INCOMPATIBLE" -and $res6.IsValid -eq $false -and $res6.Errors -match "Missing mandatory array")

# Test 7: Null Response object -> ERROR
$res7 = Test-HistoricalApiResponse -Response $null -ExpectedDates $expectedDates
Assert-Result -TestName "Null response object -> ERROR" -Condition ($res7.Outcome -eq "ERROR" -and $res7.IsValid -eq $false)

# Test 8: Missing 'daily' property -> ERROR
$noDailyObj = [PSCustomObject]@{ latitude = 31.0 }
$res8 = Test-HistoricalApiResponse -Response $noDailyObj -ExpectedDates $expectedDates
Assert-Result -TestName "Missing 'daily' object -> ERROR" -Condition ($res8.Outcome -eq "ERROR" -and $res8.IsValid -eq $false)

# Test 9: Mismatched array length (short array)
$shortArrObj = New-ValidFixture
$shortArrObj.daily.temperature_2m_max = @(35.0, 36.0, 37.0)
$res9 = Test-HistoricalApiResponse -Response $shortArrObj -ExpectedDates $expectedDates
Assert-Result -TestName "Short array length -> Validation failure" -Condition ($res9.IsValid -eq $false -and $res9.Errors -match "does not match expected count")

# Test 10: Date sequence mismatch
$wrongDateObj = New-ValidFixture
$wrongDateObj.daily.time = @("2024-06-01", "2024-06-02", "2024-06-04", "2024-06-05", "2024-06-06")
$res10 = Test-HistoricalApiResponse -Response $wrongDateObj -ExpectedDates $expectedDates
Assert-Result -TestName "Date sequence mismatch -> Validation failure" -Condition ($res10.IsValid -eq $false -and $res10.Errors -match "Date at index 2 mismatch")

# Test 11: Invalid numeric string
$nanObj = New-ValidFixture
$nanObj.daily.temperature_2m_max[3] = "invalid_temp"
$res11 = Test-HistoricalApiResponse -Response $nanObj -ExpectedDates $expectedDates
Assert-Result -TestName "Invalid numeric string -> Validation failure" -Condition ($res11.IsValid -eq $false -and $res11.Errors -match "not a valid number")

# Test 12: Incorrect unit
$wrongUnitObj = New-ValidFixture
$wrongUnitObj.daily_units.temperature_2m_max = "°F"
$res12 = Test-HistoricalApiResponse -Response $wrongUnitObj -ExpectedDates $expectedDates
Assert-Result -TestName "Incorrect unit -> Validation failure" -Condition ($res12.IsValid -eq $false -and $res12.Errors -match "Unit mismatch for 'temperature_2m_max'")

# Test 13: Legitimate 0.0 values preserved and accepted -> PASS
$zeroObj = New-ValidFixture
$zeroObj.daily.precipitation_sum = @(0.0, 0.0, 0.0, 0.0, 0.0)
$res13 = Test-HistoricalApiResponse -Response $zeroObj -ExpectedDates $expectedDates
Assert-Result -TestName "Legitimate 0.0 precipitation values accepted -> PASS" -Condition ($res13.Outcome -eq "PASS" -and $res13.IsValid -eq $true)

# Test 13b: Structural validation failure combined with missing values classified as ERROR
$structPlusMissingObj = New-ValidFixture
$structPlusMissingObj.daily.temperature_2m_max[0] = $null # missing value
$structPlusMissingObj.daily_units.temperature_2m_max = "°F" # structural error: unit mismatch
$res13b = Test-HistoricalApiResponse -Response $structPlusMissingObj -ExpectedDates $expectedDates
Assert-Result -TestName "Structural validation failure with missing values classified as ERROR" -Condition ($res13b.Outcome -eq "ERROR" -and $res13b.IsValid -eq $false)

Write-Host "`n================================================================="
Write-Host "Running Deterministic Child-Process Exit-Code Tests..." -ForegroundColor Cyan
Write-Host "================================================================="

# Create a temporary output directory for test fixtures
$testOutputDir = Join-Path ([System.IO.Path]::GetTempPath()) "agro_shift_ps_test_$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $testOutputDir -Force | Out-Null

try {
    # Tests 14-16: Deterministic HTTP transport/connection failure (ERROR)
    # Using explicit -SimulateTransportError test seam, guaranteeing 100% deterministic transport failure
    # without network port binding races or OS socket availability dependencies.

    # Test 14: Deterministic HTTP transport failure (ERROR) with -FailOnAnyModelError omitted
    # Model is configured with ExpectPass = $false (so an error does not violate an expectation of passing),
    # and -FailOnAnyModelError is NOT passed.
    # Expected outcome: ERROR recorded, but exit code is 0 because no passing expectation failed and -FailOnAnyModelError is off.
    Write-Host "Testing child execution: HTTP transport failure with ExpectPass=`$false and -FailOnAnyModelError omitted..."
    $wrapper14 = Join-Path $testOutputDir "run_test14.ps1"
    @"
    `$cfg = @(@{ Name = 'test_err'; ModelParam = ''; ExpectPass = `$false })
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg -SimulateTransportError
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper14 -Encoding UTF8

    $p14 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper14`"" -Wait -NoNewWindow -PassThru
    $exit14 = $p14.ExitCode
    Assert-Result -TestName "Transport ERROR without -FailOnAnyModelError (and ExpectPass=`$false) -> Exit code 0" -Condition ($exit14 -eq 0) -Message "Got exit code $exit14 (expected 0)"

    # Test 15: Deterministic HTTP transport failure (ERROR) with -FailOnAnyModelError enabled
    # Expected outcome: ERROR recorded, -FailOnAnyModelError is active -> exit code 1.
    Write-Host "Testing child execution: HTTP transport failure with -FailOnAnyModelError enabled..."
    $wrapper15 = Join-Path $testOutputDir "run_test15.ps1"
    @"
    `$cfg = @(@{ Name = 'test_err'; ModelParam = ''; ExpectPass = `$false })
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg -FailOnAnyModelError -SimulateTransportError
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper15 -Encoding UTF8

    $p15 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper15`"" -Wait -NoNewWindow -PassThru
    $exit15 = $p15.ExitCode
    Assert-Result -TestName "Transport ERROR with -FailOnAnyModelError enabled -> Exit code 1" -Condition ($exit15 -eq 1) -Message "Got exit code $exit15 (expected 1)"

    # Test 16: Deterministic Expectation Failure: Model expected to pass encounters transport ERROR
    # Model has ExpectPass = $true, but transport error occurs -> hasExpectationFailure = $true -> exit code 1
    Write-Host "Testing child execution: ExpectPass=`$true model encounters transport ERROR..."
    $wrapper16 = Join-Path $testOutputDir "run_test16.ps1"
    @"
    `$cfg = @(@{ Name = 'test_expect_pass'; ModelParam = ''; ExpectPass = `$true })
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg -SimulateTransportError
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper16 -Encoding UTF8

    $p16 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper16`"" -Wait -NoNewWindow -PassThru
    $exit16 = $p16.ExitCode
    Assert-Result -TestName "Model expected to PASS encounters transport ERROR -> Exit code 1" -Condition ($exit16 -eq 1) -Message "Got exit code $exit16 (expected 1)"

    # Test 17: Mock Response File providing a complete valid response -> Exit code 0
    Write-Host "Testing child execution with mock response file providing valid response..."
    $validMockFile = Join-Path $testOutputDir "mock_valid.json"
    (New-ValidFixture) | ConvertTo-Json -Depth 10 | Set-Content -Path $validMockFile -Encoding UTF8

    $wrapper17 = Join-Path $testOutputDir "run_test17.ps1"
    @"
    `$cfg = @(@{ Name = 'test_valid'; ModelParam = ''; ExpectPass = `$true })
    `$mocks = @{ 'test_valid' = '$validMockFile' }
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper17 -Encoding UTF8

    $p17 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper17`"" -Wait -NoNewWindow -PassThru
    $exit17 = $p17.ExitCode
    Assert-Result -TestName "Model expected to PASS receives valid response -> Exit code 0" -Condition ($exit17 -eq 0) -Message "Got exit code $exit17 (expected 0)"

    # Test 18: Mock Response File providing INCOMPATIBLE response to a model expected to PASS -> Exit code 1
    Write-Host "Testing child execution: INCOMPATIBLE response to model expected to PASS..."
    $nullTmaxFixture = New-ValidFixture
    $nullTmaxFixture.daily.temperature_2m_max[0] = $null
    $incompatibleMockFile = Join-Path $testOutputDir "mock_incomp.json"
    $nullTmaxFixture | ConvertTo-Json -Depth 10 | Set-Content -Path $incompatibleMockFile -Encoding UTF8

    $wrapper18 = Join-Path $testOutputDir "run_test18.ps1"
    @"
    `$cfg = @(@{ Name = 'test_incomp'; ModelParam = ''; ExpectPass = `$true })
    `$mocks = @{ 'test_incomp' = '$incompatibleMockFile' }
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper18 -Encoding UTF8

    $p18 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper18`"" -Wait -NoNewWindow -PassThru
    $exit18 = $p18.ExitCode
    Assert-Result -TestName "Model expected to PASS returns INCOMPATIBLE -> Exit code 1" -Condition ($exit18 -eq 1) -Message "Got exit code $exit18 (expected 1)"

    # Test 19: Mock Response File providing INCOMPATIBLE response to a model expected to FAIL (ExpectPass=$false) -> Exit code 0
    Write-Host "Testing child execution: Expected INCOMPATIBLE model meets expectation..."
    $wrapper19 = Join-Path $testOutputDir "run_test19.ps1"
    @"
    `$cfg = @(@{ Name = 'test_expect_incomp'; ModelParam = ''; ExpectPass = `$false })
    `$mocks = @{ 'test_expect_incomp' = '$incompatibleMockFile' }
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper19 -Encoding UTF8

    $p19 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper19`"" -Wait -NoNewWindow -PassThru
    $exit19 = $p19.ExitCode
    Assert-Result -TestName "Model expected to be INCOMPATIBLE returns INCOMPATIBLE -> Exit code 0" -Condition ($exit19 -eq 0) -Message "Got exit code $exit19 (expected 0)"

    # Test 20: Malformed JSON response -> Diagnosed as ERROR, not INCOMPATIBLE
    Write-Host "Testing child execution: Malformed JSON response..."
    $malformedJsonFile = Join-Path $testOutputDir "mock_malformed.json"
    "This is not valid JSON { missing quotes: true " | Set-Content -Path $malformedJsonFile -Encoding UTF8

    $wrapper20 = Join-Path $testOutputDir "run_test20.ps1"
    @"
    `$cfg = @(@{ Name = 'test_malformed'; ModelParam = ''; ExpectPass = `$false })
    `$mocks = @{ 'test_malformed' = '$malformedJsonFile' }
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg -MockResponseFiles `$mocks -FailOnAnyModelError
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper20 -Encoding UTF8

    $p20 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper20`"" -Wait -NoNewWindow -PassThru
    $exit20 = $p20.ExitCode
    Assert-Result -TestName "Malformed JSON diagnosed as ERROR (-FailOnAnyModelError exit 1)" -Condition ($exit20 -eq 1) -Message "Got exit code $exit20 (expected 1)"

    # Test 21: Valid JSON with unexpected structure (missing 'daily' property) -> Diagnosed as ERROR
    Write-Host "Testing child execution: Valid JSON with unexpected structure (missing daily)..."
    $unexpectedStructureFile = Join-Path $testOutputDir "mock_unexpected_struct.json"
    @{ latitude = 31.0; longitude = 31.0; error = "Some server error notice" } | ConvertTo-Json -Depth 5 | Set-Content -Path $unexpectedStructureFile -Encoding UTF8

    $wrapper21 = Join-Path $testOutputDir "run_test21.ps1"
    @"
    `$cfg = @(@{ Name = 'test_unexpected'; ModelParam = ''; ExpectPass = `$false })
    `$mocks = @{ 'test_unexpected' = '$unexpectedStructureFile' }
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg -MockResponseFiles `$mocks -FailOnAnyModelError
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper21 -Encoding UTF8

    $p21 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper21`"" -Wait -NoNewWindow -PassThru
    $exit21 = $p21.ExitCode
    Assert-Result -TestName "Unexpected JSON structure diagnosed as ERROR (-FailOnAnyModelError exit 1)" -Condition ($exit21 -eq 1) -Message "Got exit code $exit21 (expected 1)"

    # Fixture snapshot helper supporting PowerShell 5.1 and Core
    function Get-FixtureSnapshot {
        param(
            [Parameter(Mandatory = $true)]
            [string]$FixtureRoot
        )

        $root = [System.IO.Path]::GetFullPath($FixtureRoot)

        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            throw "Fixture directory does not exist: $root"
        }

        $snapshot = @{}

        $files = @(
            Get-ChildItem -LiteralPath $root -File -Recurse |
            Where-Object { $_.Extension -ieq ".json" } |
            Sort-Object FullName
        )

        $rootWithSep = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

        foreach ($file in $files) {
            $fullPath = $file.FullName
            if ($fullPath.StartsWith($rootWithSep, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relativePath = $fullPath.Substring($rootWithSep.Length).Replace('\', '/')
            } else {
                $relativePath = $file.Name
            }

            $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256

            $snapshot[$relativePath] = [PSCustomObject]@{
                RelativePath = $relativePath
                Length       = $file.Length
                SHA256       = $hash.Hash
            }
        }

        return $snapshot
    }

    function Test-SnapshotsEqual {
        param(
            [hashtable]$SnapA,
            [hashtable]$SnapB
        )

        if ($SnapA.Count -ne $SnapB.Count) {
            return $false
        }

        foreach ($key in $SnapA.Keys) {
            if (-not $SnapB.ContainsKey($key)) {
                return $false
            }
            $itemA = $SnapA[$key]
            $itemB = $SnapB[$key]
            if ($itemA.Length -ne $itemB.Length -or $itemA.SHA256 -ne $itemB.SHA256) {
                return $false
            }
        }
        return $true
    }

    $committedFixturesDir = [System.IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot "../../docs/fixtures/historical_api")
    )

    # Test 22: Complete recursive SHA-256 baseline check for default validation run
    Write-Host "Testing child execution: Validating full SHA-256 fixture snapshot protection during default run..."
    $baselineSnapshot = Get-FixtureSnapshot -FixtureRoot $committedFixturesDir

    $wrapper22 = Join-Path $testOutputDir "run_test22.ps1"
    @"
    `$cfg = @(@{ Name = 'test_safe_default'; ModelParam = ''; ExpectPass = `$true })
    `$mocks = @{ 'test_safe_default' = '$validMockFile' }
    & '$scriptPath' -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper22 -Encoding UTF8

    $p22 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper22`"" -Wait -NoNewWindow -PassThru
    $exit22 = $p22.ExitCode
    $afterSnapshot22 = Get-FixtureSnapshot -FixtureRoot $committedFixturesDir
    $fixturesEqual22 = Test-SnapshotsEqual -SnapA $baselineSnapshot -SnapB $afterSnapshot22
    Assert-Result -TestName "Default validation run does not modify any committed fixtures (all files SHA256 verified)" -Condition ($exit22 -eq 0 -and $fixturesEqual22) -Message "Exit: $exit22, Equal: $fixturesEqual22"

    # Test 23: Explicit committed fixture directory without -SaveCommittedFixtures -> Rejected (Exit 1)
    Write-Host "Testing child execution: Explicit committed fixture directory without authorization switch..."
    $wrapper23 = Join-Path $testOutputDir "run_test23.ps1"
    @"
    `$cfg = @(@{ Name = 'test_unauth'; ModelParam = ''; ExpectPass = `$true })
    `$mocks = @{ 'test_unauth' = '$validMockFile' }
    & '$scriptPath' -OutputDir '$committedFixturesDir' -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper23 -Encoding UTF8

    $p23 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper23`"" -Wait -NoNewWindow -PassThru
    $exit23 = $p23.ExitCode
    $afterSnapshot23 = Get-FixtureSnapshot -FixtureRoot $committedFixturesDir
    $fixturesEqual23 = Test-SnapshotsEqual -SnapA $baselineSnapshot -SnapB $afterSnapshot23
    Assert-Result -TestName "Explicit committed fixture path rejected without -SaveCommittedFixtures (Exit 1)" -Condition ($exit23 -eq 1 -and $fixturesEqual23) -Message "Exit: $exit23, Equal: $fixturesEqual23"

    # Test 24: Descendant of committed fixture directory without -SaveCommittedFixtures -> Rejected (Exit 1)
    Write-Host "Testing child execution: Descendant of committed fixture directory without authorization switch..."
    $descendantPath = Join-Path $committedFixturesDir "subfolder_not_yet_created"
    $wrapper24 = Join-Path $testOutputDir "run_test24.ps1"
    @"
    `$cfg = @(@{ Name = 'test_descendant'; ModelParam = ''; ExpectPass = `$true })
    `$mocks = @{ 'test_descendant' = '$validMockFile' }
    & '$scriptPath' -OutputDir '$descendantPath' -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper24 -Encoding UTF8

    $p24 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper24`"" -Wait -NoNewWindow -PassThru
    $exit24 = $p24.ExitCode
    $descendantWasNotCreated = -not (Test-Path -LiteralPath $descendantPath)
    $afterSnapshot24 = Get-FixtureSnapshot -FixtureRoot $committedFixturesDir
    $fixturesEqual24 = Test-SnapshotsEqual -SnapA $baselineSnapshot -SnapB $afterSnapshot24
    Assert-Result -TestName "Descendant of committed fixtures rejected and directory not created (Exit 1)" -Condition ($exit24 -eq 1 -and $descendantWasNotCreated -and $fixturesEqual24) -Message "Exit: $exit24, NotCreated: $descendantWasNotCreated"

    # Test 25: Relative path resolving to committed fixture directory without -SaveCommittedFixtures -> Rejected (Exit 1)
    Write-Host "Testing child execution: Relative path resolving to committed fixtures without authorization switch..."
    $relativePathToFixtures = "docs/fixtures/historical_api"
    $wrapper25 = Join-Path $testOutputDir "run_test25.ps1"
    @"
    `$cfg = @(@{ Name = 'test_rel'; ModelParam = ''; ExpectPass = `$true })
    `$mocks = @{ 'test_rel' = '$validMockFile' }
    & '$scriptPath' -OutputDir '$relativePathToFixtures' -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper25 -Encoding UTF8

    $p25 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper25`"" -Wait -NoNewWindow -PassThru
    $exit25 = $p25.ExitCode
    $afterSnapshot25 = Get-FixtureSnapshot -FixtureRoot $committedFixturesDir
    $fixturesEqual25 = Test-SnapshotsEqual -SnapA $baselineSnapshot -SnapB $afterSnapshot25
    Assert-Result -TestName "Relative path to committed fixtures rejected without -SaveCommittedFixtures (Exit 1)" -Condition ($exit25 -eq 1 -and $fixturesEqual25) -Message "Exit: $exit25, Equal: $fixturesEqual25"

    # Test 26: Sibling prefix path (e.g. historical_api_backup) -> NOT rejected merely for sharing a prefix
    Write-Host "Testing child execution: Sibling directory sharing name prefix..."
    $siblingDir = Join-Path ([System.IO.Path]::GetDirectoryName($committedFixturesDir)) "historical_api_backup_test_$([Guid]::NewGuid().ToString('N'))"
    $wrapper26 = Join-Path $testOutputDir "run_test26.ps1"
    @"
    `$cfg = @(@{ Name = 'test_sibling'; ModelParam = ''; ExpectPass = `$true })
    `$mocks = @{ 'test_sibling' = '$validMockFile' }
    & '$scriptPath' -OutputDir '$siblingDir' -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper26 -Encoding UTF8

    try {
        $p26 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper26`"" -Wait -NoNewWindow -PassThru
        $exit26 = $p26.ExitCode
        $siblingFileWritten = Test-Path -LiteralPath (Join-Path $siblingDir "test_sibling_raw.json")
        Assert-Result -TestName "Sibling prefix directory allowed without false rejection (Exit 0)" -Condition ($exit26 -eq 0 -and $siblingFileWritten) -Message "Exit: $exit26, SiblingFile: $siblingFileWritten"
    } finally {
        if (Test-Path -LiteralPath $siblingDir) {
            Remove-Item -LiteralPath $siblingDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Test 27: Isolated project tree tests for protected fixture destination guard
    # We construct a full temporary project tree:
    #   <temp-root>/scripts/validate_historical_models.ps1
    #   <temp-root>/docs/fixtures/historical_api/
    # In this isolated tree, the copied validator's own $PSScriptRoot resolves to <temp-root>/scripts,
    # so its protected destination is specifically <temp-root>/docs/fixtures/historical_api.
    # This exercises the real protected-path guard without modifying the repository's real fixtures.
    Write-Host "Setting up isolated temporary project tree for protected-path authorization tests..."
    $isolatedProjectRoot = Join-Path $testOutputDir "isolated_repo_tree"
    $isolatedScriptsDir = Join-Path $isolatedProjectRoot "scripts"
    $isolatedFixturesDir = Join-Path $isolatedProjectRoot "docs/fixtures/historical_api"
    New-Item -ItemType Directory -Path $isolatedScriptsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $isolatedFixturesDir -Force | Out-Null

    # Copy script and existing fixtures into isolated tree
    $isolatedScriptPath = Join-Path $isolatedScriptsDir "validate_historical_models.ps1"
    Copy-Item -LiteralPath $scriptPath -Destination $isolatedScriptPath -Force
    Get-ChildItem -LiteralPath $committedFixturesDir -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $isolatedFixturesDir -Force
    }

    $isolatedMockFile = Join-Path $testOutputDir "isolated_mock_valid.json"
    (New-ValidFixture) | ConvertTo-Json -Depth 10 | Set-Content -Path $isolatedMockFile -Encoding UTF8

    # Test 27A: In isolated tree, writing to its protected fixture directory without -SaveCommittedFixtures -> Rejected (Exit 1)
    Write-Host "Testing child execution (Isolated Tree): Writing to protected fixture destination without -SaveCommittedFixtures..."
    $wrapper27A = Join-Path $testOutputDir "run_test27A.ps1"
    @"
    `$cfg = @(@{ Name = 'test_iso_unauth'; ModelParam = ''; ExpectPass = `$true })
    `$mocks = @{ 'test_iso_unauth' = '$isolatedMockFile' }
    & '$isolatedScriptPath' -OutputDir '$isolatedFixturesDir' -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper27A -Encoding UTF8

    $p27A = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper27A`"" -Wait -NoNewWindow -PassThru
    $exit27A = $p27A.ExitCode
    $realFixturesAfter27A = Get-FixtureSnapshot -FixtureRoot $committedFixturesDir
    $realFixturesUntouched27A = Test-SnapshotsEqual -SnapA $baselineSnapshot -SnapB $realFixturesAfter27A
    Assert-Result -TestName "Isolated project: Protected fixture destination rejected without -SaveCommittedFixtures (Exit 1)" -Condition ($exit27A -eq 1 -and $realFixturesUntouched27A) -Message "Exit: $exit27A, RealFixturesUntouched: $realFixturesUntouched27A"

    # Test 27B: In isolated tree, writing to its protected fixture directory WITH -SaveCommittedFixtures -> Accepted (Exit 0)
    Write-Host "Testing child execution (Isolated Tree): Writing to protected fixture destination WITH -SaveCommittedFixtures..."
    $wrapper27B = Join-Path $testOutputDir "run_test27B.ps1"
    @"
    `$cfg = @(@{ Name = 'test_iso_auth'; ModelParam = ''; ExpectPass = `$true })
    `$mocks = @{ 'test_iso_auth' = '$isolatedMockFile' }
    & '$isolatedScriptPath' -OutputDir '$isolatedFixturesDir' -SaveCommittedFixtures -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper27B -Encoding UTF8

    $p27B = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper27B`"" -Wait -NoNewWindow -PassThru
    $exit27B = $p27B.ExitCode
    $isolatedWrittenFile = Join-Path $isolatedFixturesDir "test_iso_auth_raw.json"
    $fileWasWrittenInIsolated = Test-Path -LiteralPath $isolatedWrittenFile
    $realFixturesAfter27B = Get-FixtureSnapshot -FixtureRoot $committedFixturesDir
    $realFixturesUntouched27B = Test-SnapshotsEqual -SnapA $baselineSnapshot -SnapB $realFixturesAfter27B
    Assert-Result -TestName "Isolated project: Protected fixture destination accepted WITH -SaveCommittedFixtures (Exit 0)" -Condition ($exit27B -eq 0 -and $fileWasWrittenInIsolated -and $realFixturesUntouched27B) -Message "Exit: $exit27B, FileWritten: $fileWasWrittenInIsolated, RealFixturesUntouched: $realFixturesUntouched27B"

    # Test 27C: Normal temporary directory with -SaveCommittedFixtures allowed and writes output (Exit 0)
    Write-Host "Testing child execution: Ordinary temporary directory with -SaveCommittedFixtures..."
    $safeAuthorizedDir = Join-Path $testOutputDir "safe_authorized_ordinary"
    $wrapper27C = Join-Path $testOutputDir "run_test27C.ps1"
    @"
    `$cfg = @(@{ Name = 'test_auth_ord'; ModelParam = ''; ExpectPass = `$true })
    `$mocks = @{ 'test_auth_ord' = '$validMockFile' }
    & '$scriptPath' -OutputDir '$safeAuthorizedDir' -SaveCommittedFixtures -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper27C -Encoding UTF8

    $p27C = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper27C`"" -Wait -NoNewWindow -PassThru
    $exit27C = $p27C.ExitCode
    $authFileWrittenOrd = Test-Path -LiteralPath (Join-Path $safeAuthorizedDir "test_auth_ord_raw.json")
    $realFixturesAfter27C = Get-FixtureSnapshot -FixtureRoot $committedFixturesDir
    $realFixturesUntouched27C = Test-SnapshotsEqual -SnapA $baselineSnapshot -SnapB $realFixturesAfter27C
    Assert-Result -TestName "Ordinary directory with -SaveCommittedFixtures allowed and writes output (Exit 0)" -Condition ($exit27C -eq 0 -and $authFileWrittenOrd -and $realFixturesUntouched27C) -Message "Exit: $exit27C, Written: $authFileWrittenOrd"

    # =================================================================
    # Tests 28-30: Verification Evidence Runner (record_verification_evidence.ps1) Exit Code Semantics
    # =================================================================
    $recorderScript = Join-Path $PSScriptRoot "../../scripts/record_verification_evidence.ps1"

    # Test 28: Mock test of evidence runner exit semantics when a stage fails -> exits 1, preserves logs and summary
    Write-Host "Testing evidence runner exit semantics: Simulating stage failure in isolated environment..."
    $runnerTestDir = Join-Path $testOutputDir "runner_test_env"
    $runnerEvidenceDir28 = Join-Path $runnerTestDir "evidence28"
    New-Item -ItemType Directory -Path $runnerEvidenceDir28 -Force | Out-Null

    $runnerContent = Get-Content -Path $recorderScript -Raw -Encoding UTF8
    $mockStages28 = @"
`$summary = [System.Collections.Generic.List[hashtable]]::new()
`$summary.Add((Run-Stage -StageName "Mock Pass 1" -Command "Write-Host Stage1" -OutPrefix "mock_1"))
`$summary.Add((Run-Stage -StageName "Mock Fail 2" -Command "exit 2" -OutPrefix "mock_2"))
`$summary.Add((Run-Stage -StageName "Mock Pass 3" -Command "Write-Host Stage3" -OutPrefix "mock_3"))
"@
    $startIndex = $runnerContent.IndexOf("# --- BEGIN VERIFICATION STAGES ---")
    $endIndex = $runnerContent.IndexOf("# --- END VERIFICATION STAGES ---") + "# --- END VERIFICATION STAGES ---".Length
    $modified28 = $runnerContent.Substring(0, $startIndex) + $mockStages28 + $runnerContent.Substring($endIndex)
    $fakeRunner28 = Join-Path $runnerTestDir "fake_runner_fail.ps1"
    Set-Content -Path $fakeRunner28 -Value $modified28 -Encoding UTF8

    $wrapper28 = Join-Path $testOutputDir "run_test28.ps1"
    @"
    & '$fakeRunner28' -RepoRoot '$PSScriptRoot/../..' -OutputDir '$runnerEvidenceDir28'
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper28 -Encoding UTF8

    $p28 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper28`"" -Wait -NoNewWindow -PassThru
    $exit28 = $p28.ExitCode
    Assert-Result -TestName "Evidence runner exits with code 1 when a verification stage fails" -Condition ($exit28 -eq 1) -Message "Exit: $exit28 (expected 1)"

    # Test 29: Verify failure evidence and logs were preserved on disk before exit 1
    Write-Host "Testing evidence runner: Verifying logs and summary were written before failure exit..."
    $sumPath28 = Join-Path $runnerEvidenceDir28 "verification_summary.json"
    $summaryExists = Test-Path $sumPath28
    $mock2ExitPreserved = $false
    if ($summaryExists) {
        $rawJson = Get-Content -Path $sumPath28 -Raw | ConvertFrom-Json
        $failStage = $rawJson.Stages | Where-Object { $_.Stage -eq "Mock Fail 2" }
        if ($rawJson.OverallStatus -eq "FAIL" -and $null -ne $failStage -and [int]$failStage.ExitCode -eq 2) {
            $mock2ExitPreserved = $true
        }
    }
    Assert-Result -TestName "Evidence runner preserved failure summary and exit code 2 before exiting" -Condition ($summaryExists -and $mock2ExitPreserved) -Message "SummaryExists: $summaryExists, ExitCodePreserved: $mock2ExitPreserved"

    # Test 30: Mock test of evidence runner exit semantics when all stages succeed -> exits 0
    Write-Host "Testing evidence runner exit semantics: Simulating all stages passing..."
    $runnerEvidenceDir30 = Join-Path $runnerTestDir "evidence30"
    New-Item -ItemType Directory -Path $runnerEvidenceDir30 -Force | Out-Null

    $mockStages30 = @"
`$summary = [System.Collections.Generic.List[hashtable]]::new()
`$summary.Add((Run-Stage -StageName "Mock Pass 1" -Command "Write-Host Stage1" -OutPrefix "mock_pass_1"))
`$summary.Add((Run-Stage -StageName "Mock Pass 2" -Command "Write-Host Stage2" -OutPrefix "mock_pass_2"))
"@
    $modified30 = $runnerContent.Substring(0, $startIndex) + $mockStages30 + $runnerContent.Substring($endIndex)
    $fakeRunner30 = Join-Path $runnerTestDir "fake_runner_pass.ps1"
    Set-Content -Path $fakeRunner30 -Value $modified30 -Encoding UTF8

    $wrapper30 = Join-Path $testOutputDir "run_test30.ps1"
    @"
    & '$fakeRunner30' -RepoRoot '$PSScriptRoot/../..' -OutputDir '$runnerEvidenceDir30'
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper30 -Encoding UTF8

    $p30 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper30`"" -Wait -NoNewWindow -PassThru
    $exit30 = $p30.ExitCode
    Assert-Result -TestName "Evidence runner exits with code 0 when all verification stages pass" -Condition ($exit30 -eq 0) -Message "Exit: $exit30 (expected 0)"

    # Test 31: Regression test for native process failure exit code (e.g. cmd.exe /c exit 7)
    Write-Host "Testing evidence runner: Simulating failing native command with exit code 7..."
    $runnerEvidenceDir31 = Join-Path $runnerTestDir "evidence31"
    New-Item -ItemType Directory -Path $runnerEvidenceDir31 -Force | Out-Null

    $mockStages31 = @"
`$summary = [System.Collections.Generic.List[hashtable]]::new()
`$summary.Add((Run-Stage -StageName "Mock Pass 1" -Command "Write-Host Stage1" -OutPrefix "mock_pass_1"))
`$summary.Add((Run-Stage -StageName "Native Fail 7" -Command "cmd.exe /c exit 7" -OutPrefix "native_fail_7"))
`$summary.Add((Run-Stage -StageName "Mock Later Pass" -Command "Write-Host StageLater" -OutPrefix "mock_later_pass"))
"@
    $modified31 = $runnerContent.Substring(0, $startIndex) + $mockStages31 + $runnerContent.Substring($endIndex)
    $fakeRunner31 = Join-Path $runnerTestDir "fake_runner_native7.ps1"
    Set-Content -Path $fakeRunner31 -Value $modified31 -Encoding UTF8

    $wrapper31 = Join-Path $testOutputDir "run_test31.ps1"
    @"
    & '$fakeRunner31' -RepoRoot '$PSScriptRoot/../..' -OutputDir '$runnerEvidenceDir31'
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper31 -Encoding UTF8

    $p31 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper31`"" -Wait -NoNewWindow -PassThru
    $exit31 = $p31.ExitCode
    Assert-Result -TestName "Evidence runner exits with code 1 when a native command fails with code 7" -Condition ($exit31 -eq 1) -Message "Exit: $exit31 (expected 1)"

    $sumPath31 = Join-Path $runnerEvidenceDir31 "verification_summary.json"
    $summary31Exists = Test-Path $sumPath31
    $native7Preserved = $false
    $laterPassRecorded = $false
    if ($summary31Exists) {
        $rawJson31 = Get-Content -Path $sumPath31 -Raw | ConvertFrom-Json
        $failStage31 = $rawJson31.Stages | Where-Object { $_.Stage -eq "Native Fail 7" }
        $laterStage31 = $rawJson31.Stages | Where-Object { $_.Stage -eq "Mock Later Pass" }
        if ($rawJson31.OverallStatus -eq "FAIL" -and $null -ne $failStage31 -and [int]$failStage31.ExitCode -eq 7) {
            $native7Preserved = $true
        }
        if ($null -ne $laterStage31 -and [int]$laterStage31.ExitCode -eq 0) {
            $laterPassRecorded = $true
        }
    }
    Assert-Result -TestName "Evidence runner preserved native exit code 7 and prevented later pass from hiding failure" -Condition ($summary31Exists -and $native7Preserved -and $laterPassRecorded) -Message "SummaryExists: $summary31Exists, Native7Preserved: $native7Preserved, LaterPassRecorded: $laterPassRecorded"

    # Test 32: Process-launch failure handling with subsequent stage recovery
    Write-Host "Testing evidence runner: Simulating process-launch failure in Run-Stage with subsequent stage recovery..."
    $runnerEvidenceDir32 = Join-Path $runnerTestDir "evidence32"
    New-Item -ItemType Directory -Path $runnerEvidenceDir32 -Force | Out-Null

    # Generate runner where Run-Stage uses AGROSHIFT_TEST_FAIL_STAGE to fail only the first stage
    $fakeRunner32 = Join-Path $runnerTestDir "fake_runner_launch_fail.ps1"
    $mockStages32 = @"
`$summary = [System.Collections.Generic.List[hashtable]]::new()
`$summary.Add((Run-Stage -StageName "Launch Fail Stage" -Command "Write-Host Stage1" -OutPrefix "launch_fail"))
`$summary.Add((Run-Stage -StageName "Later Passing Stage" -Command "Write-Host StageLater" -OutPrefix "later_stage"))
"@
    $modified32 = $runnerContent.Substring(0, $runnerContent.IndexOf("# --- BEGIN VERIFICATION STAGES ---")) + $mockStages32 + $runnerContent.Substring($runnerContent.IndexOf("# --- END VERIFICATION STAGES ---") + "# --- END VERIFICATION STAGES ---".Length)
    Set-Content -Path $fakeRunner32 -Value $modified32 -Encoding UTF8

    $wrapper32 = Join-Path $testOutputDir "run_test32.ps1"
    @"
    `$env:AGROSHIFT_TEST_FAIL_STAGE = 'Launch Fail Stage'
    try {
        & '$fakeRunner32' -RepoRoot '$PSScriptRoot/../..' -OutputDir '$runnerEvidenceDir32'
        exit `$LASTEXITCODE
    } finally {
        Remove-Item env:AGROSHIFT_TEST_FAIL_STAGE -ErrorAction SilentlyContinue
    }
"@ | Set-Content -Path $wrapper32 -Encoding UTF8

    $p32 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper32`"" -Wait -NoNewWindow -PassThru
    $exit32 = $p32.ExitCode
    Assert-Result -TestName "Evidence runner exits with code 1 when process launch fails" -Condition ($exit32 -eq 1) -Message "Exit: $exit32 (expected 1)"

    $sumPath32 = Join-Path $runnerEvidenceDir32 "verification_summary.json"
    $summary32Exists = Test-Path $sumPath32
    $launchFailRecorded = $false
    $laterStageSucceeded = $false
    if ($summary32Exists) {
        $rawJson32 = Get-Content -Path $sumPath32 -Raw | ConvertFrom-Json
        $failStage32 = $rawJson32.Stages | Where-Object { $_.Stage -eq "Launch Fail Stage" }
        $passStage32 = $rawJson32.Stages | Where-Object { $_.Stage -eq "Later Passing Stage" }
        if ($rawJson32.OverallStatus -eq "FAIL" -and $null -ne $failStage32 -and [int]$failStage32.ExitCode -eq -1 -and -not [string]::IsNullOrWhiteSpace($failStage32.LaunchError)) {
            $launchFailRecorded = $true
        }
        if ($null -ne $passStage32 -and [int]$passStage32.ExitCode -eq 0 -and $null -eq $passStage32.LaunchError) {
            $laterStageSucceeded = $true
        }
    }
    Assert-Result -TestName "Evidence runner recorded launch failure as exit code -1 and preserved launch error details" -Condition ($summary32Exists -and $launchFailRecorded) -Message "SummaryExists: $summary32Exists, LaunchFailRecorded: $launchFailRecorded"
    Assert-Result -TestName "Subsequent stage was launched and completed successfully with exit code 0" -Condition ($summary32Exists -and $laterStageSucceeded) -Message "SummaryExists: $summary32Exists, LaterStageSucceeded: $laterStageSucceeded"

    # =================================================================
    # Tests 33-38: Content-Based Source Tree Fingerprint Unit Tests
    # =================================================================
    Write-Host "Testing Get-SourceTreeFingerprint in isolated synthetic test repositories..."
    $synthRepoDir = Join-Path $testOutputDir "synth_repo"
    New-Item -ItemType Directory -Path $synthRepoDir -Force | Out-Null

    # Initialize real isolated git repository for deterministic content hashing tests
    git -C $synthRepoDir init | Out-Null
    git -C $synthRepoDir config user.name "AgroShift Test" | Out-Null
    git -C $synthRepoDir config user.email "test@agroshift.local" | Out-Null

    New-Item -ItemType Directory -Path (Join-Path $synthRepoDir "lib") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $synthRepoDir "test") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $synthRepoDir "artifacts/runs") -Force | Out-Null

    $trackedTestFile = Join-Path $synthRepoDir "lib/file1.dart"
    Set-Content -Path $trackedTestFile -Value "// initial content" -Encoding UTF8
    $trackedBinaryFile = Join-Path $synthRepoDir "lib/model.bin"
    [System.IO.File]::WriteAllBytes($trackedBinaryFile, [byte[]]@(0x01, 0x02, 0x03, 0x04, 0x05))

    git -C $synthRepoDir add . | Out-Null
    git -C $synthRepoDir commit -m "initial commit" | Out-Null

    # Test 33: Baseline fingerprint establishment
    $recorderText = Get-Content -Path $recorderScript -Raw -Encoding UTF8
    $fpFuncStartIndex = $recorderText.IndexOf("function Get-SourceTreeFingerprint {")
    $fpFuncEndIndex = $recorderText.IndexOf("`$initialSourceTreeObj = Get-SourceTreeFingerprint")
    $fpFuncDef = $recorderText.Substring($fpFuncStartIndex, $fpFuncEndIndex - $fpFuncStartIndex)
    . ([scriptblock]::Create($fpFuncDef))

    $fpBase = Get-SourceTreeFingerprint -Root $synthRepoDir
    Assert-Result -TestName "Content fingerprint established on clean baseline synthetic repository" -Condition ($fpBase.Fingerprint -ne "unknown" -and $fpBase.FileCount -eq 2) -Message "FP: $($fpBase.Fingerprint), Count: $($fpBase.FileCount)"

    # Test 34: Tracked text file modified -> fingerprint changes
    Set-Content -Path $trackedTestFile -Value "// modified content" -Encoding UTF8
    $fpTrackedMod = Get-SourceTreeFingerprint -Root $synthRepoDir
    Assert-Result -TestName "Content fingerprint changes when tracked text file content changes" -Condition ($fpTrackedMod.Fingerprint -ne $fpBase.Fingerprint -and $fpTrackedMod.Fingerprint -ne "unknown") -Message "Before: $($fpBase.Fingerprint), After: $($fpTrackedMod.Fingerprint)"

    # Revert tracked file
    git -C $synthRepoDir checkout -- lib/file1.dart | Out-Null

    # Test 35: Untracked file created, then untracked file content changes without path changing
    $untrackedFile = Join-Path $synthRepoDir "test/untracked_script.dart"
    Set-Content -Path $untrackedFile -Value "// untracked version 1" -Encoding UTF8
    $fpUntracked1 = Get-SourceTreeFingerprint -Root $synthRepoDir
    Set-Content -Path $untrackedFile -Value "// untracked version 2 modified bytes" -Encoding UTF8
    $fpUntracked2 = Get-SourceTreeFingerprint -Root $synthRepoDir
    Assert-Result -TestName "Content fingerprint changes when existing untracked file content changes at same path" -Condition ($fpUntracked1.Fingerprint -ne $fpUntracked2.Fingerprint -and $fpUntracked2.Fingerprint -ne "unknown") -Message "V1: $($fpUntracked1.Fingerprint), V2: $($fpUntracked2.Fingerprint)"
    Remove-Item -Path $untrackedFile -Force

    # Test 36: Binary file content changes -> fingerprint changes
    [System.IO.File]::WriteAllBytes($trackedBinaryFile, [byte[]]@(0x01, 0x02, 0x03, 0xFF, 0xEE))
    $fpBinaryMod = Get-SourceTreeFingerprint -Root $synthRepoDir
    Assert-Result -TestName "Content fingerprint changes when binary file bytes change" -Condition ($fpBinaryMod.Fingerprint -ne $fpBase.Fingerprint -and $fpBinaryMod.Fingerprint -ne "unknown") -Message "Base: $($fpBase.Fingerprint), BinaryMod: $($fpBinaryMod.Fingerprint)"
    git -C $synthRepoDir checkout -- lib/model.bin | Out-Null

    # Test 37: Expected artifacts directory output mutations do NOT alter source fingerprint
    $artifactFile = Join-Path $synthRepoDir "artifacts/runs/new_run_evidence.txt"
    Set-Content -Path $artifactFile -Value "Some test run output evidence text" -Encoding UTF8
    $fpArtifactAdded = Get-SourceTreeFingerprint -Root $synthRepoDir
    Assert-Result -TestName "Generated artifacts additions are excluded and do not cause false source mutation" -Condition ($fpArtifactAdded.Fingerprint -eq $fpBase.Fingerprint) -Message "Expected: $($fpBase.Fingerprint), Got: $($fpArtifactAdded.Fingerprint)"

    # Test 38: Inaccessible or unreadable file reports failure honestly (unknown)
    # Simulate by pointing Get-SourceTreeFingerprint to an invalid non-git directory or unreadable target
    $invalidDir = Join-Path $testOutputDir "non_existent_folder_abc123"
    $fpFailed = Get-SourceTreeFingerprint -Root $invalidDir
    Assert-Result -TestName "Fingerprinting failure is reported honestly as unknown with error detail" -Condition ($fpFailed.Fingerprint -eq "unknown" -and -not [string]::IsNullOrWhiteSpace($fpFailed.Error)) -Message "FP: $($fpFailed.Fingerprint), Error: $($fpFailed.Error)"

    # =================================================================
    # Tests 39-43: Inventory Modification Tests (Add, Delete, Rename)
    # =================================================================
    # Test 39: Adding a tracked file changes the composite fingerprint
    $newTrackedFile = Join-Path $synthRepoDir "lib/new_module.dart"
    Set-Content -Path $newTrackedFile -Value "// new tracked module" -Encoding UTF8
    git -C $synthRepoDir add lib/new_module.dart | Out-Null
    $fpTrackedAdd = Get-SourceTreeFingerprint -Root $synthRepoDir
    Assert-Result -TestName "Adding a tracked file changes the composite fingerprint" -Condition ($fpTrackedAdd.Fingerprint -ne $fpBase.Fingerprint -and $fpTrackedAdd.FileCount -eq 3) -Message "BaseCount: $($fpBase.FileCount), NewCount: $($fpTrackedAdd.FileCount)"
    git -C $synthRepoDir rm -f lib/new_module.dart | Out-Null

    # Test 40: Adding an eligible non-ignored untracked file changes the fingerprint
    $newUntrackedFile = Join-Path $synthRepoDir "lib/untracked_feature.dart"
    Set-Content -Path $newUntrackedFile -Value "// untracked feature code" -Encoding UTF8
    $fpUntrackedAdd = Get-SourceTreeFingerprint -Root $synthRepoDir
    Assert-Result -TestName "Adding an eligible untracked file changes the composite fingerprint" -Condition ($fpUntrackedAdd.Fingerprint -ne $fpBase.Fingerprint -and $fpUntrackedAdd.FileCount -eq 3) -Message "BaseCount: $($fpBase.FileCount), NewCount: $($fpUntrackedAdd.FileCount)"

    # Test 41: Deleting an eligible untracked file restores the base inventory
    Remove-Item -Path $newUntrackedFile -Force
    $fpUntrackedDel = Get-SourceTreeFingerprint -Root $synthRepoDir
    Assert-Result -TestName "Deleting an eligible untracked file restores the base inventory fingerprint" -Condition ($fpUntrackedDel.Fingerprint -eq $fpBase.Fingerprint -and $fpUntrackedDel.FileCount -eq 2) -Message "Got: $($fpUntrackedDel.Fingerprint), Expected: $($fpBase.Fingerprint)"

    # Test 42: Deleting a tracked file from disk triggers honest failure reporting (missing file)
    Remove-Item -Path $trackedTestFile -Force
    $fpTrackedDel = Get-SourceTreeFingerprint -Root $synthRepoDir
    Assert-Result -TestName "Deleting a tracked file without git staging reports unknown with missing file error" -Condition ($fpTrackedDel.Fingerprint -eq "unknown" -and $fpTrackedDel.Error -like "*missing or inaccessible*") -Message "FP: $($fpTrackedDel.Fingerprint), Error: $($fpTrackedDel.Error)"
    git -C $synthRepoDir checkout -- lib/file1.dart | Out-Null

    # Test 43: Renaming a file changes the composite fingerprint
    git -C $synthRepoDir mv lib/file1.dart lib/file1_renamed.dart | Out-Null
    $fpRenamed = Get-SourceTreeFingerprint -Root $synthRepoDir
    Assert-Result -TestName "Renaming a file changes the composite fingerprint and preserves count" -Condition ($fpRenamed.Fingerprint -ne $fpBase.Fingerprint -and $fpRenamed.FileCount -eq 2) -Message "BaseFP: $($fpBase.Fingerprint), RenamedFP: $($fpRenamed.Fingerprint)"
    git -C $synthRepoDir mv lib/file1_renamed.dart lib/file1.dart | Out-Null

    # =================================================================
    # Test 44: Run-Stage Error Classification Separation
    # =================================================================
    # Assert that Run-Stage distinguishes launch failure (code -1, LaunchError set) from normal exit
    # and that normal command does not set LaunchError, OutputError, or WaitError
    Write-Host "Testing Run-Stage error classification separation..."
    $runnerEvidenceDir44 = Join-Path $runnerTestDir "evidence44"
    New-Item -ItemType Directory -Path $runnerEvidenceDir44 -Force | Out-Null

    $fakeRunner44 = Join-Path $runnerTestDir "fake_runner_error_class.ps1"
    $mockStages44 = @"
`$summary = [System.Collections.Generic.List[hashtable]]::new()
`$summary.Add((Run-Stage -StageName "Normal Stage" -Command "Write-Host 'normal output'" -OutPrefix "normal_stage"))
`$summary.Add((Run-Stage -StageName "Nonzero Normal Stage" -Command "cmd.exe /c exit 5" -OutPrefix "nonzero_stage"))
"@
    $modified44 = $runnerContent.Substring(0, $runnerContent.IndexOf("# --- BEGIN VERIFICATION STAGES ---")) + $mockStages44 + $runnerContent.Substring($runnerContent.IndexOf("# --- END VERIFICATION STAGES ---") + "# --- END VERIFICATION STAGES ---".Length)
    Set-Content -Path $fakeRunner44 -Value $modified44 -Encoding UTF8

    $wrapper44 = Join-Path $testOutputDir "run_test44.ps1"
    @"
    & '$fakeRunner44' -RepoRoot '$PSScriptRoot/../..' -OutputDir '$runnerEvidenceDir44'
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper44 -Encoding UTF8

    $p44 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper44`"" -Wait -NoNewWindow -PassThru
    $sumPath44 = Join-Path $runnerEvidenceDir44 "verification_summary.json"
    $summary44Exists = Test-Path $sumPath44
    $normalClassifiedCorrectly = $false
    $nonzeroClassifiedCorrectly = $false
    if ($summary44Exists) {
        $rawJson44 = Get-Content -Path $sumPath44 -Raw | ConvertFrom-Json
        $normalStage = $rawJson44.Stages | Where-Object { $_.Stage -eq "Normal Stage" }
        $nonzeroStage = $rawJson44.Stages | Where-Object { $_.Stage -eq "Nonzero Normal Stage" }
        if ($null -ne $normalStage -and [int]$normalStage.ExitCode -eq 0 -and $null -eq $normalStage.LaunchError -and $null -eq $normalStage.OutputError -and $null -eq $normalStage.WaitError) {
            $normalClassifiedCorrectly = $true
        }
        if ($null -ne $nonzeroStage -and [int]$nonzeroStage.ExitCode -eq 5 -and $null -eq $nonzeroStage.LaunchError -and $null -eq $nonzeroStage.OutputError -and $null -eq $nonzeroStage.WaitError) {
            $nonzeroClassifiedCorrectly = $true
        }
    }
    Assert-Result -TestName "Run-Stage does not misclassify normal execution or nonzero exit as a launch failure" -Condition ($summary44Exists -and $normalClassifiedCorrectly -and $nonzeroClassifiedCorrectly) -Message "NormalOK: $normalClassifiedCorrectly, NonzeroOK: $nonzeroClassifiedCorrectly"

    # =================================================================
    # Tests 45-48: Targeted Error Path Tests (Preparation, Output, Wait, Evidence Write)
    # =================================================================
    # Test 45: Stage Preparation Failure (temporary script creation failure)
    Write-Host "Testing Run-Stage: Stage preparation failure handling..."
    $runnerEvidenceDir45 = Join-Path $runnerTestDir "evidence45"
    New-Item -ItemType Directory -Path $runnerEvidenceDir45 -Force | Out-Null

    $fakeRunner45 = Join-Path $runnerTestDir "fake_runner_prep_fail.ps1"
    $mockStages45 = @"
`$summary = [System.Collections.Generic.List[hashtable]]::new()
`$summary.Add((Run-Stage -StageName "Prep Fail Stage" -Command "Write-Host Stage1" -OutPrefix "prep_fail"))
`$summary.Add((Run-Stage -StageName "Later Passing Stage" -Command "Write-Host StageLater" -OutPrefix "later_stage"))
"@
    $modified45 = $runnerContent.Substring(0, $runnerContent.IndexOf("# --- BEGIN VERIFICATION STAGES ---")) + $mockStages45 + $runnerContent.Substring($runnerContent.IndexOf("# --- END VERIFICATION STAGES ---") + "# --- END VERIFICATION STAGES ---".Length)
    Set-Content -Path $fakeRunner45 -Value $modified45 -Encoding UTF8

    $wrapper45 = Join-Path $testOutputDir "run_test45.ps1"
    @"
    `$env:AGROSHIFT_TEST_FAIL_PREPARATION = 'Prep Fail Stage'
    try {
        & '$fakeRunner45' -RepoRoot '$PSScriptRoot/../..' -OutputDir '$runnerEvidenceDir45'
        exit `$LASTEXITCODE
    } finally {
        Remove-Item env:AGROSHIFT_TEST_FAIL_PREPARATION -ErrorAction SilentlyContinue
    }
"@ | Set-Content -Path $wrapper45 -Encoding UTF8

    $p45 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper45`"" -Wait -NoNewWindow -PassThru
    $sumPath45 = Join-Path $runnerEvidenceDir45 "verification_summary.json"
    $summary45Exists = Test-Path $sumPath45
    $prepFailClassified = $false
    $laterStageRan45 = $false
    if ($summary45Exists) {
        $rawJson45 = Get-Content -Path $sumPath45 -Raw | ConvertFrom-Json
        $failStage45 = $rawJson45.Stages | Where-Object { $_.Stage -eq "Prep Fail Stage" }
        $passStage45 = $rawJson45.Stages | Where-Object { $_.Stage -eq "Later Passing Stage" }
        if ($rawJson45.OverallStatus -eq "FAIL" -and $null -ne $failStage45 -and [int]$failStage45.ExitCode -eq -1 -and -not [string]::IsNullOrWhiteSpace($failStage45.PreparationError) -and $null -eq $failStage45.LaunchError) {
            $prepFailClassified = $true
        }
        if ($null -ne $passStage45 -and [int]$passStage45.ExitCode -eq 0) {
            $laterStageRan45 = $true
        }
    }
    Assert-Result -TestName "Stage preparation failure is recorded with PreparationError and allows subsequent stage" -Condition ($p45.ExitCode -eq 1 -and $summary45Exists -and $prepFailClassified -and $laterStageRan45) -Message "Exit: $($p45.ExitCode), PrepFailOK: $prepFailClassified, LaterRan: $laterStageRan45"

    # Test 46: Output Collection Failure
    Write-Host "Testing Run-Stage: Output collection failure handling..."
    $runnerEvidenceDir46 = Join-Path $runnerTestDir "evidence46"
    New-Item -ItemType Directory -Path $runnerEvidenceDir46 -Force | Out-Null

    $fakeRunner46 = Join-Path $runnerTestDir "fake_runner_output_fail.ps1"
    $mockStages46 = @"
`$summary = [System.Collections.Generic.List[hashtable]]::new()
`$summary.Add((Run-Stage -StageName "Output Fail Stage" -Command "Write-Host StageOutput" -OutPrefix "output_fail"))
`$summary.Add((Run-Stage -StageName "Later Passing Stage" -Command "Write-Host StageLater" -OutPrefix "later_stage"))
"@
    $modified46 = $runnerContent.Substring(0, $runnerContent.IndexOf("# --- BEGIN VERIFICATION STAGES ---")) + $mockStages46 + $runnerContent.Substring($runnerContent.IndexOf("# --- END VERIFICATION STAGES ---") + "# --- END VERIFICATION STAGES ---".Length)
    Set-Content -Path $fakeRunner46 -Value $modified46 -Encoding UTF8

    $wrapper46 = Join-Path $testOutputDir "run_test46.ps1"
    @"
    `$env:AGROSHIFT_TEST_FAIL_OUTPUT = 'Output Fail Stage'
    try {
        & '$fakeRunner46' -RepoRoot '$PSScriptRoot/../..' -OutputDir '$runnerEvidenceDir46'
        exit `$LASTEXITCODE
    } finally {
        Remove-Item env:AGROSHIFT_TEST_FAIL_OUTPUT -ErrorAction SilentlyContinue
    }
"@ | Set-Content -Path $wrapper46 -Encoding UTF8

    $p46 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper46`"" -Wait -NoNewWindow -PassThru
    $sumPath46 = Join-Path $runnerEvidenceDir46 "verification_summary.json"
    $summary46Exists = Test-Path $sumPath46
    $outputFailClassified = $false
    if ($summary46Exists) {
        $rawJson46 = Get-Content -Path $sumPath46 -Raw | ConvertFrom-Json
        $failStage46 = $rawJson46.Stages | Where-Object { $_.Stage -eq "Output Fail Stage" }
        if ($rawJson46.OverallStatus -eq "FAIL" -and $null -ne $failStage46 -and [int]$failStage46.ExitCode -eq 1 -and -not [string]::IsNullOrWhiteSpace($failStage46.OutputError) -and $null -eq $failStage46.LaunchError) {
            $outputFailClassified = $true
        }
    }
    Assert-Result -TestName "Output collection failure is classified with OutputError rather than LaunchError" -Condition ($p46.ExitCode -eq 1 -and $summary46Exists -and $outputFailClassified) -Message "Exit: $($p46.ExitCode), OutputFailOK: $outputFailClassified"

    # Test 49: Output-Reader Initialization Failure (simulating ReadToEndAsync initialization exception)
    Write-Host "Testing Run-Stage: Output-reader initialization failure handling..."
    $runnerEvidenceDir49 = Join-Path $runnerTestDir "evidence49"
    New-Item -ItemType Directory -Path $runnerEvidenceDir49 -Force | Out-Null

    $fakeRunner49 = Join-Path $runnerTestDir "fake_runner_reader_init_fail.ps1"
    $mockStages49 = @"
`$summary = [System.Collections.Generic.List[hashtable]]::new()
`$summary.Add((Run-Stage -StageName "Reader Init Fail Stage" -Command "Write-Host StageReaderInit" -OutPrefix "reader_init_fail"))
`$summary.Add((Run-Stage -StageName "Later Passing Stage" -Command "Write-Host StageLater" -OutPrefix "later_stage"))
"@
    $modified49 = $runnerContent.Substring(0, $runnerContent.IndexOf("# --- BEGIN VERIFICATION STAGES ---")) + $mockStages49 + $runnerContent.Substring($runnerContent.IndexOf("# --- END VERIFICATION STAGES ---") + "# --- END VERIFICATION STAGES ---".Length)
    Set-Content -Path $fakeRunner49 -Value $modified49 -Encoding UTF8

    $wrapper49 = Join-Path $testOutputDir "run_test49.ps1"
    @"
    `$env:AGROSHIFT_TEST_FAIL_READER_INIT = 'Reader Init Fail Stage'
    try {
        & '$fakeRunner49' -RepoRoot '$PSScriptRoot/../..' -OutputDir '$runnerEvidenceDir49'
        exit `$LASTEXITCODE
    } finally {
        Remove-Item env:AGROSHIFT_TEST_FAIL_READER_INIT -ErrorAction SilentlyContinue
    }
"@ | Set-Content -Path $wrapper49 -Encoding UTF8

    $p49 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper49`"" -Wait -NoNewWindow -PassThru
    $sumPath49 = Join-Path $runnerEvidenceDir49 "verification_summary.json"
    $summary49Exists = Test-Path $sumPath49
    $readerInitFailClassified = $false
    $laterStageRan49 = $false
    if ($summary49Exists) {
        $rawJson49 = Get-Content -Path $sumPath49 -Raw | ConvertFrom-Json
        $failStage49 = $rawJson49.Stages | Where-Object { $_.Stage -eq "Reader Init Fail Stage" }
        $passStage49 = $rawJson49.Stages | Where-Object { $_.Stage -eq "Later Passing Stage" }
        if ($rawJson49.OverallStatus -eq "FAIL" -and $null -ne $failStage49 -and [int]$failStage49.ExitCode -eq 1 -and -not [string]::IsNullOrWhiteSpace($failStage49.OutputError) -and $null -eq $failStage49.LaunchError) {
            $readerInitFailClassified = $true
        }
        if ($null -ne $passStage49 -and [int]$passStage49.ExitCode -eq 0) {
            $laterStageRan49 = $true
        }
    }
    Assert-Result -TestName "Output-reader initialization failure is classified with OutputError, preserves LaunchError null, allows subsequent stage, and exits runner with code 1" -Condition ($p49.ExitCode -eq 1 -and $summary49Exists -and $readerInitFailClassified -and $laterStageRan49) -Message "Exit: $($p49.ExitCode), ReaderInitOK: $readerInitFailClassified, LaterRan: $laterStageRan49"

    # Test 47: Process Wait Failure
    Write-Host "Testing Run-Stage: Process wait failure handling..."
    $runnerEvidenceDir47 = Join-Path $runnerTestDir "evidence47"
    New-Item -ItemType Directory -Path $runnerEvidenceDir47 -Force | Out-Null

    $fakeRunner47 = Join-Path $runnerTestDir "fake_runner_wait_fail.ps1"
    $mockStages47 = @"
`$summary = [System.Collections.Generic.List[hashtable]]::new()
`$summary.Add((Run-Stage -StageName "Wait Fail Stage" -Command "Write-Host StageWait" -OutPrefix "wait_fail"))
`$summary.Add((Run-Stage -StageName "Later Passing Stage" -Command "Write-Host StageLater" -OutPrefix "later_stage"))
"@
    $modified47 = $runnerContent.Substring(0, $runnerContent.IndexOf("# --- BEGIN VERIFICATION STAGES ---")) + $mockStages47 + $runnerContent.Substring($runnerContent.IndexOf("# --- END VERIFICATION STAGES ---") + "# --- END VERIFICATION STAGES ---".Length)
    Set-Content -Path $fakeRunner47 -Value $modified47 -Encoding UTF8

    $wrapper47 = Join-Path $testOutputDir "run_test47.ps1"
    @"
    `$env:AGROSHIFT_TEST_FAIL_WAIT = 'Wait Fail Stage'
    try {
        & '$fakeRunner47' -RepoRoot '$PSScriptRoot/../..' -OutputDir '$runnerEvidenceDir47'
        exit `$LASTEXITCODE
    } finally {
        Remove-Item env:AGROSHIFT_TEST_FAIL_WAIT -ErrorAction SilentlyContinue
    }
"@ | Set-Content -Path $wrapper47 -Encoding UTF8

    $p47 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper47`"" -Wait -NoNewWindow -PassThru
    $sumPath47 = Join-Path $runnerEvidenceDir47 "verification_summary.json"
    $summary47Exists = Test-Path $sumPath47
    $waitFailClassified = $false
    if ($summary47Exists) {
        $rawJson47 = Get-Content -Path $sumPath47 -Raw | ConvertFrom-Json
        $failStage47 = $rawJson47.Stages | Where-Object { $_.Stage -eq "Wait Fail Stage" }
        if ($rawJson47.OverallStatus -eq "FAIL" -and $null -ne $failStage47 -and [int]$failStage47.ExitCode -eq 1 -and -not [string]::IsNullOrWhiteSpace($failStage47.WaitError) -and $null -eq $failStage47.LaunchError) {
            $waitFailClassified = $true
        }
    }
    Assert-Result -TestName "Process wait failure is classified with WaitError rather than LaunchError" -Condition ($p47.ExitCode -eq 1 -and $summary47Exists -and $waitFailClassified) -Message "Exit: $($p47.ExitCode), WaitFailOK: $waitFailClassified"

    # Test 48: Evidence Write Failure
    Write-Host "Testing Run-Stage: Evidence write failure handling..."
    $runnerEvidenceDir48 = Join-Path $runnerTestDir "evidence48"
    New-Item -ItemType Directory -Path $runnerEvidenceDir48 -Force | Out-Null

    $fakeRunner48 = Join-Path $runnerTestDir "fake_runner_evidence_fail.ps1"
    $mockStages48 = @"
`$summary = [System.Collections.Generic.List[hashtable]]::new()
`$summary.Add((Run-Stage -StageName "Evidence Write Fail Stage" -Command "Write-Host StageEvidence" -OutPrefix "evidence_fail"))
`$summary.Add((Run-Stage -StageName "Later Passing Stage" -Command "Write-Host StageLater" -OutPrefix "later_stage"))
"@
    $modified48 = $runnerContent.Substring(0, $runnerContent.IndexOf("# --- BEGIN VERIFICATION STAGES ---")) + $mockStages48 + $runnerContent.Substring($runnerContent.IndexOf("# --- END VERIFICATION STAGES ---") + "# --- END VERIFICATION STAGES ---".Length)
    Set-Content -Path $fakeRunner48 -Value $modified48 -Encoding UTF8

    $wrapper48 = Join-Path $testOutputDir "run_test48.ps1"
    @"
    `$env:AGROSHIFT_TEST_FAIL_EVIDENCE_WRITE = 'Evidence Write Fail Stage'
    try {
        & '$fakeRunner48' -RepoRoot '$PSScriptRoot/../..' -OutputDir '$runnerEvidenceDir48'
        exit `$LASTEXITCODE
    } finally {
        Remove-Item env:AGROSHIFT_TEST_FAIL_EVIDENCE_WRITE -ErrorAction SilentlyContinue
    }
"@ | Set-Content -Path $wrapper48 -Encoding UTF8

    $p48 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper48`"" -Wait -NoNewWindow -PassThru
    $sumPath48 = Join-Path $runnerEvidenceDir48 "verification_summary.json"
    $summary48Exists = Test-Path $sumPath48
    $evidenceWriteFailClassified = $false
    if ($summary48Exists) {
        $rawJson48 = Get-Content -Path $sumPath48 -Raw | ConvertFrom-Json
        $failStage48 = $rawJson48.Stages | Where-Object { $_.Stage -eq "Evidence Write Fail Stage" }
        if ($rawJson48.OverallStatus -eq "FAIL" -and $null -ne $failStage48 -and [int]$failStage48.ExitCode -eq 1 -and -not [string]::IsNullOrWhiteSpace($failStage48.EvidenceWriteError) -and $null -eq $failStage48.LaunchError) {
            $evidenceWriteFailClassified = $true
        }
    }
    Assert-Result -TestName "Evidence write failure fails stage honestly and records EvidenceWriteError" -Condition ($p48.ExitCode -eq 1 -and $summary48Exists -and $evidenceWriteFailClassified) -Message "Exit: $($p48.ExitCode), EvidenceWriteFailOK: $evidenceWriteFailClassified"

    # Test 50: Configuration validation - missing or whitespace Name -> throws / non-zero exit
    Write-Host "Testing child execution: Malformed configuration (missing Name)..."
    $wrapper50 = Join-Path $testOutputDir "run_test50.ps1"
    @"
    `$cfg = @(@{ Name = ''; ModelParam = ''; ExpectPass = `$true })
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper50 -Encoding UTF8

    $p50 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper50`"" -Wait -NoNewWindow -PassThru
    $exit50 = $p50.ExitCode
    Assert-Result -TestName "Configuration with missing Name causes non-zero exit code" -Condition ($exit50 -ne 0) -Message "Got exit code $exit50"

    # Test 51: Configuration validation - invalid ModelParam type -> throws / non-zero exit
    Write-Host "Testing child execution: Malformed configuration (non-string ModelParam)..."
    $wrapper51 = Join-Path $testOutputDir "run_test51.ps1"
    @"
    `$cfg = @(@{ Name = 'test_invalid_param'; ModelParam = 12345; ExpectPass = `$true })
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper51 -Encoding UTF8

    $p51 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper51`"" -Wait -NoNewWindow -PassThru
    $exit51 = $p51.ExitCode
    Assert-Result -TestName "Configuration with non-string ModelParam causes non-zero exit code" -Condition ($exit51 -ne 0) -Message "Got exit code $exit51"

    # Test 52: Configuration validation - missing or non-boolean ExpectPass -> throws / non-zero exit
    Write-Host "Testing child execution: Malformed configuration (non-boolean ExpectPass)..."
    $wrapper52 = Join-Path $testOutputDir "run_test52.ps1"
    @"
    `$cfg = @(@{ Name = 'test_no_bool'; ModelParam = ''; ExpectPass = 'yes' })
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper52 -Encoding UTF8

    $p52 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper52`"" -Wait -NoNewWindow -PassThru
    $exit52 = $p52.ExitCode
    Assert-Result -TestName "Configuration with non-boolean ExpectPass causes non-zero exit code" -Condition ($exit52 -ne 0) -Message "Got exit code $exit52"

    # Test 53: Configuration validation - duplicate configuration names -> throws / non-zero exit
    Write-Host "Testing child execution: Duplicate configuration names..."
    $wrapper53 = Join-Path $testOutputDir "run_test53.ps1"
    @"
    `$cfg = @(
        @{ Name = 'duplicate_model'; ModelParam = '&models=era5'; ExpectPass = `$true },
        @{ Name = 'duplicate_model'; ModelParam = '&models=era5_seamless'; ExpectPass = `$true }
    )
    & '$scriptPath' -OutputDir '$testOutputDir' -ConfigsOverride `$cfg
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper53 -Encoding UTF8

    $p53 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper53`"" -Wait -NoNewWindow -PassThru
    $exit53 = $p53.ExitCode
    Assert-Result -TestName "Duplicate configuration names cause non-zero exit code" -Condition ($exit53 -ne 0) -Message "Got exit code $exit53"

    # Test 54: Test-discovery safeguard detects non-standard *_tests.dart filenames
    Write-Host "Testing test discovery safeguard: Detects non-standard *_tests.dart filenames..."
    $runnerScriptPath = "$PSScriptRoot/../../scripts/record_verification_evidence.ps1"
    $dummyRepoDir = Join-Path $testOutputDir "dummy_repo_with_invalid_test_filename"
    $dummyTestDir = Join-Path $dummyRepoDir "test/sub"
    New-Item -ItemType Directory -Path $dummyTestDir -Force | Out-Null
    $offendingFilePath = Join-Path $dummyTestDir "sample_invalid_tests.dart"
    Set-Content -Path $offendingFilePath -Value "// Dummy test file"

    $p54 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$runnerScriptPath`" -RepoRoot `"$dummyRepoDir`" -OutputDir `"$testOutputDir/evidence54`"" -Wait -NoNewWindow -PassThru
    $exit54 = $p54.ExitCode
    Assert-Result -TestName "Test discovery safeguard causes non-zero exit when *_tests.dart exists" -Condition ($exit54 -ne 0) -Message "Got exit code $exit54"

    # Test 55: Test-discovery safeguard succeeds when only standard *_test.dart files exist
    Write-Host "Testing test discovery safeguard: Passes when only standard *_test.dart filenames exist..."
    Remove-Item -Path $offendingFilePath -Force
    $validFilePath = Join-Path $dummyTestDir "sample_valid_test.dart"
    Set-Content -Path $validFilePath -Value "// Dummy valid test file"

    # We source the safeguard check or run record_verification_evidence.ps1 in dry-run/mock context
    $wrapper55 = Join-Path $testOutputDir "run_test55.ps1"
    @"
    `$ErrorActionPreference = 'Stop'
    . '$runnerScriptPath'
    Assert-ValidTestFilenames -Root '$dummyRepoDir'
    exit 0
"@ | Set-Content -Path $wrapper55 -Encoding UTF8

    $p55 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper55`"" -Wait -NoNewWindow -PassThru
    $exit55 = $p55.ExitCode
    Assert-Result -TestName "Test discovery safeguard passes when only standard *_test.dart exist" -Condition ($exit55 -eq 0) -Message "Got exit code $exit55"

} finally {
    if (Test-Path $testOutputDir) {
        Remove-Item -Path $testOutputDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n================================================================="
Write-Host "Running Optional Live Open-Meteo Integration Test..." -ForegroundColor Cyan
Write-Host "================================================================="
$canReachLiveApi = $false
try {
    $probe = Invoke-WebRequest -Uri "https://archive-api.open-meteo.com/v1/archive?latitude=31.0&longitude=31.0&start_date=2024-06-01&end_date=2024-06-01&daily=temperature_2m_max&timezone=Africa%2FCairo" -Method Get -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($probe.StatusCode -eq 200) {
        $canReachLiveApi = $true
    }
} catch {
    Write-Host "Notice: Live Open-Meteo API is unreachable ($($_.Exception.Message)). Skipping live integration test." -ForegroundColor Yellow
}

$deterministicTestsRun = $script:testsRun
$deterministicTestsPassed = $script:testsPassed
$liveTestExecuted = $false
$liveTestPassed = $false

if ($canReachLiveApi) {
    Write-Host "Executing live Open-Meteo validation sweep (output isolated to temp dir to protect committed fixtures)..."
    $liveTempDir = Join-Path ([System.IO.Path]::GetTempPath()) "agro_shift_live_sweep_$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $liveTempDir -Force | Out-Null
    try {
        $pLive = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -OutputDir `"$liveTempDir`" -FailOnAnyModelError" -Wait -NoNewWindow -PassThru
        $exitLive = $pLive.ExitCode
        $liveTestExecuted = $true
        $liveTestPassed = ($exitLive -eq 0)
        Assert-Result -TestName "Live Open-Meteo sweep execution completed successfully (Exit code 0)" -Condition ($exitLive -eq 0) -Message "Got exit code $exitLive"
    } finally {
        if (Test-Path $liveTempDir) {
            Remove-Item -Path $liveTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host " [SKIPPED] Live Open-Meteo sweep skipped due to network/firewall unavailability." -ForegroundColor Yellow
}

Write-Host "`n================================================================="
Write-Host "Execution Summary:"
Write-Host "Deterministic Tests: $deterministicTestsPassed / $deterministicTestsRun passed." -ForegroundColor $(if ($deterministicTestsPassed -eq $deterministicTestsRun) { "Green" } else { "Red" })
if ($liveTestExecuted) {
    Write-Host "Optional Live Integration Test: Executed (Result: $(if ($liveTestPassed) { 'PASS' } else { 'FAIL' }))" -ForegroundColor $(if ($liveTestPassed) { "Green" } else { "Red" })
} else {
    Write-Host "Optional Live Integration Test: NOT RUN / SKIPPED" -ForegroundColor Yellow
}
Write-Host "Total Suite Checks: $testsPassed / $testsRun passed." -ForegroundColor $(if ($testsPassed -eq $testsRun) { "Green" } else { "Red" })
Write-Host "================================================================="

if ($testsPassed -ne $testsRun) {
    exit 1
}
exit 0
