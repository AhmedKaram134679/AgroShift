# AgroShift - Open-Meteo Historical Weather API Model Validation Script
# Queries Open-Meteo Historical Weather API for Kafr El-Sheikh across four model configurations:
# 1. era5
# 2. era5_seamless
# 3. era5_land
# 4. default (no models parameter)

param(
    [string]$OutputDir = "$PSScriptRoot/../docs/fixtures/historical_api"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$lat = "31.10"
$lon = "30.95"
$startDate = "2024-06-01"
$endDate = "2024-06-05"
$tz = "Africa%2FCairo"
$daily = "temperature_2m_max,temperature_2m_min,et0_fao_evapotranspiration,precipitation_sum"

$configs = @(
    @{ Name = "era5"; ModelParam = "&models=era5" },
    @{ Name = "era5_seamless"; ModelParam = "&models=era5_seamless" },
    @{ Name = "era5_land"; ModelParam = "&models=era5_land" },
    @{ Name = "default"; ModelParam = "" }
)

Write-Host "================================================================="
Write-Host "Open-Meteo Historical API Model Validation"
Write-Host "Target: Lat $lat, Lon $lon ($startDate to $endDate, TZ: Africa/Cairo)"
Write-Host "Timestamp (UTC): $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
Write-Host "=================================================================`n"

foreach ($cfg in $configs) {
    $url = "https://archive-api.open-meteo.com/v1/archive?latitude=$lat&longitude=$lon&start_date=$startDate&end_date=$endDate&daily=$daily&timezone=$tz$($cfg.ModelParam)"
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
        
        $dailyObj = $response.daily
        $dates = $dailyObj.time
        $tMax = $dailyObj.temperature_2m_max
        $tMin = $dailyObj.temperature_2m_min
        $et0 = $dailyObj.et0_fao_evapotranspiration
        $precip = $dailyObj.precipitation_sum

        $nullEt0Count = ($et0 | Where-Object { $_ -eq $null }).Count
        $nullPrecipCount = ($precip | Where-Object { $_ -eq $null }).Count
        $nullTmaxCount = ($tMax | Where-Object { $_ -eq $null }).Count
        $nullTminCount = ($tMin | Where-Object { $_ -eq $null }).Count

        Write-Host "Array Lengths: $($dates.Count) days"
        Write-Host "Null Counts: Tmax: $nullTmaxCount, Tmin: $nullTminCount, ET0: $nullEt0Count, Precip: $nullPrecipCount"
        
        if ($nullEt0Count -gt 0 -or $nullPrecipCount -gt 0) {
            Write-Host "Assessment: FAIL - Missing mandatory agricultural variables`n" -ForegroundColor Red
        } else {
            Write-Host "Assessment: PASS - All 4 variables populated`n" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Assessment: ERROR - $($_.Exception.Message)`n" -ForegroundColor Red
        throw $_
    }
}
