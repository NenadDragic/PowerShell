Import-Module WebAdministration

# Hent alle Application Pools
$appPools = Get-ChildItem IIS:\AppPools
$fejledePools = @()

foreach ($pool in $appPools) {
    $status = (Get-WebAppPoolState -Name $pool.Name).Value
    if ($status -eq "Started") {
        try {
            Write-Host "Genstarter Application Pool: $($pool.Name)"
            Restart-WebAppPool -Name $pool.Name -ErrorAction Stop
        }
        catch {
            Write-Warning "FEJL ved genstart af '$($pool.Name)': $_"
            $fejledePools += $pool.Name
        }
    }
}

# Vis fejlede pools til sidst
if ($fejledePools.Count -gt 0) {
    Write-Host "`nFølgende Application Pools kunne ikke genstartes:" -ForegroundColor Red
    $fejledePools | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
} else {
    Write-Host "`nAlle Application Pools blev genstartet uden fejl." -ForegroundColor Green
}
