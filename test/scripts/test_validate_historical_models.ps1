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

    # Test 27: Explicit committed fixture directory WITH -SaveCommittedFixtures -> Allowed by authorization guard
    Write-Host "Testing child execution: Isolated mock fixture copy with -SaveCommittedFixtures..."
    # To test authorized writing safely without mutating real committed fixtures, we test against a dedicated temp directory
    $safeAuthorizedDir = Join-Path $testOutputDir "safe_authorized_fixtures"
    $wrapper27 = Join-Path $testOutputDir "run_test27.ps1"
    @"
    `$cfg = @(@{ Name = 'test_auth'; ModelParam = ''; ExpectPass = `$true })
    `$mocks = @{ 'test_auth' = '$validMockFile' }
    & '$scriptPath' -OutputDir '$safeAuthorizedDir' -SaveCommittedFixtures -ConfigsOverride `$cfg -MockResponseFiles `$mocks
    exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapper27 -Encoding UTF8

    $p27 = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$wrapper27`"" -Wait -NoNewWindow -PassThru
    $exit27 = $p27.ExitCode
    $authFileWritten = Test-Path -LiteralPath (Join-Path $safeAuthorizedDir "test_auth_raw.json")
    Assert-Result -TestName "Normal directory with -SaveCommittedFixtures allowed and writes output (Exit 0)" -Condition ($exit27 -eq 0 -and $authFileWritten) -Message "Exit: $exit27, Written: $authFileWritten"

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
        $pLive = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -OutputDir `"$liveTempDir`"" -Wait -NoNewWindow -PassThru
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
