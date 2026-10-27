try {
    $ErrorActionPreference = 'Stop'
    dart format --output=none --set-exit-if-changed lib/ test/
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.ToString())
    exit 1
}