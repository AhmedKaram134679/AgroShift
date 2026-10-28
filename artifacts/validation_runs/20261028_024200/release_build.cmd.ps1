try {
    $ErrorActionPreference = 'Stop'
    flutter build apk --release
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.ToString())
    exit 1
}