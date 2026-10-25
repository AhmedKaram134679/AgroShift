# AgroShift - Open-Meteo Historical Weather API Model Validation Script
# Queries Open-Meteo Historical Weather API across four model configurations:
# 1. era5
# 2. era5_seamless
# 3. era5_land
# 4. default (no models parameter)

param(
    [string]$OutputDir = "$PSScriptRoot/../docs/fixtures/historical_api",
    [switch]$FailOnAnyModelError = $false
)

$ErrorActionPreference = "Stop"

function Test-HistoricalApiResponse {
    param(
        [Parameter(Mandatory = $true)]
        $Response,
        [Parameter(Mandatory = $true)]
        [string[]]$ExpectedDates,
        [Parameter(Mandatory = $false)]
        [hashtable]$ExpectedUnits = @{
            "temperature_2m_max"         = "$([char]0x00B0)C"
            "temperature_2m_min"         = "$([char]0x00B0)C"
            "et0_fao_evapotranspiration" = "mm"
            "precipitation_sum"          = "mm"
        }
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    if ($null -eq $Response) {
        $errors.Add("Response object is null")
        return @{ IsValid = $false; Errors = $errors }
    }

    if ($null -eq $Response.daily) {
        $errors.Add("Missing 'daily' object in response")
        return @{ IsValid = $false; Errors = $errors }
    }

    $daily = $Response.daily
    $dailyUnits = $Response.daily_units

    # 1. Date array verification
    $dates = $daily.time
    if ($null -eq $dates) {
        $errors.Add("Missing 'daily.time' date array")
    } else {
        if ($dates.Count -ne $ExpectedDates.Count) {
            $errors.Add("Date array length ($($dates.Count)) does not match expected length ($($ExpectedDates.Count))")
        }
        for ($i = 0; $i -lt [Math]::Min($dates.Count, $ExpectedDates.Count); $i++) {
            if ($dates[$i] -ne $ExpectedDates[$i]) {
                $errors.Add("Date at index $i mismatch: got '$($dates[$i])', expected '$($ExpectedDates[$i])'")
            }
        }
    }

    # 2. Units verification
    if ($null -eq $dailyUnits) {
        $errors.Add("Missing 'daily_units' object in response")
    } else {
        foreach ($key in $ExpectedUnits.Keys) {
            $expectedUnit = $ExpectedUnits[$key]
            $actualUnit = $dailyUnits.$key
            if ($actualUnit -ne $expectedUnit) {
                $errors.Add("Unit mismatch for '$key': got '$actualUnit', expected '$expectedUnit'")
            }
        }
    }

    # 3. Variable arrays verification (all 4 required variables)
    $requiredVars = @("temperature_2m_max", "temperature_2m_min", "et0_fao_evapotranspiration", "precipitation_sum")
    $nullCounts = @{}

    foreach ($varName in $requiredVars) {
        $arr = $daily.$varName
        if ($null -eq $arr) {
            $errors.Add("Missing mandatory array '$varName'")
            $nullCounts[$varName] = -1
            continue
        }

        if ($arr.Count -ne $ExpectedDates.Count) {
            $errors.Add("Array '$varName' count ($($arr.Count)) does not match expected count ($($ExpectedDates.Count))")
        }

        $varNullCount = 0
        for ($i = 0; $i -lt $arr.Count; $i++) {
            $val = $arr[$i]
            if ($null -eq $val) {
                $varNullCount++
            } else {
                # Verify numeric validity (not NaN or Infinity)
                $dVal = 0.0
                if (-not [double]::TryParse("$val", [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$dVal)) {
                    $errors.Add("Value at '$varName' index $i ('$val') is not a valid number")
                } elseif ([double]::IsNaN($dVal) -or [double]::IsInfinity($dVal)) {
                    $errors.Add("Value at '$varName' index $i is NaN or Infinity")
                }
            }
        }
        $nullCounts[$varName] = $varNullCount
        if ($varNullCount -gt 0) {
            $errors.Add("Array '$varName' contains $varNullCount null observations")
        }
    }

    return @{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors
        NullCounts = $nullCounts
    }
}

# Export function for external test consumption if sourced
if ($MyInvocation.InvocationName -ne '.') {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $lat = "31.10"
    $lon = "30.95"
    $startDate = "2024-06-01"
    $endDate = "2024-06-05"
    $tz = "Africa%2FCairo"
    $daily = "temperature_2m_max,temperature_2m_min,et0_fao_evapotranspiration,precipitation_sum"

    # Compute expected dates deterministically
    $sDt = [DateTime]::ParseExact($startDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
    $eDt = [DateTime]::ParseExact($endDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
    $expectedDatesList = [System.Collections.Generic.List[string]]::new()
    for ($cur = $sDt; $cur -le $eDt; $cur = $cur.AddDays(1)) {
        $expectedDatesList.Add($cur.ToString("yyyy-MM-dd"))
    }

    $configs = @(
        @{ Name = "era5"; ModelParam = "&models=era5"; ExpectPass = $true },
        @{ Name = "era5_seamless"; ModelParam = "&models=era5_seamless"; ExpectPass = $true },
        @{ Name = "era5_land"; ModelParam = "&models=era5_land"; ExpectPass = $false },
        @{ Name = "default"; ModelParam = ""; ExpectPass = $true }
    )

    Write-Host "================================================================="
    Write-Host "Open-Meteo Historical API Model Validation"
    Write-Host "Target: Lat $lat, Lon $lon ($startDate to $endDate, TZ: Africa/Cairo)"
    Write-Host "Timestamp (UTC): $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    Write-Host "Expected Days: $($expectedDatesList.Count) ($($expectedDatesList -join ', '))"
    Write-Host "=================================================================`n"

    $overallSuccess = $true

    foreach ($cfg in $configs) {
        $url = "https://archive-api.open-meteo.com/v1/archive?latitude=$lat&longitude=$lon&start_date=$startDate&end_date=$endDate&daily=$daily&timezone=$tz$($cfg.ModelParam)"
        Write-Host "-----------------------------------------------------------------"
        Write-Host "Configuration: $($cfg.Name)"
        Write-Host "URL: $url"

        try {
            $startTime = Get-Date
            $response = Invoke-RestMethod -Uri $url -Method Get
            $endTime = Get-Date
            $durationMs = ($endTime - $startTime).TotalMilliseconds

            $filePath = Join-Path $OutputDir "$($cfg.Name)_raw.json"
            $json = $response | ConvertTo-Json -Depth 10
            Set-Content -Path $filePath -Value $json -Encoding UTF8

            Write-Host "HTTP Status: 200 OK ($([math]::Round($durationMs)) ms)"
            Write-Host "Saved Raw Response: $filePath"
            Write-Host "Returned Coordinates: ($($response.latitude), $($response.longitude)), Elevation: $($response.elevation) m"

            $validation = Test-HistoricalApiResponse -Response $response -ExpectedDates $expectedDatesList
            $nullCounts = $validation.NullCounts

            Write-Host "Null Counts: Tmax: $($nullCounts['temperature_2m_max']), Tmin: $($nullCounts['temperature_2m_min']), ET0: $($nullCounts['et0_fao_evapotranspiration']), Precip: $($nullCounts['precipitation_sum'])"

            if ($validation.IsValid) {
                Write-Host "Assessment: PASS - All 4 variables populated and valid`n" -ForegroundColor Green
                if (-not $cfg.ExpectPass) {
                    Write-Host "WARNING: Configuration '$($cfg.Name)' was expected to fail but passed!" -ForegroundColor Yellow
                }
            } else {
                Write-Host "Assessment: FAIL - Validation errors:" -ForegroundColor Red
                foreach ($err in $validation.Errors) {
                    Write-Host " - $err" -ForegroundColor Red
                }
                Write-Host ""
                if ($cfg.ExpectPass) {
                    $overallSuccess = $false
                }
            }
        }
        catch {
            Write-Host "Assessment: HTTP/REQUEST ERROR - $($_.Exception.Message)`n" -ForegroundColor Red
            if ($cfg.ExpectPass) {
                $overallSuccess = $false
            }
        }
    }

    if (-not $overallSuccess) {
        Write-Host "Overall Validation: FAILED" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "Overall Validation: SUCCEEDED" -ForegroundColor Green
        exit 0
    }
}
