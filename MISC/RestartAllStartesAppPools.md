# Restart All Started App Pools - RestartAllStartesAppPools.ps1

This script restarts every currently-running IIS Application Pool on the local machine and reports any that failed to restart.

## How it works

1. Imports the `WebAdministration` module.
2. Gets all Application Pools via `Get-ChildItem IIS:\AppPools`.
3. For each pool currently in the `Started` state, restarts it with `Restart-WebAppPool`, catching and recording any errors.
4. Prints a summary: either a list of pools that failed to restart, or a confirmation that all pools restarted successfully.

## Usage

Run locally on an IIS server with administrative privileges.

```powershell
.\RestartAllStartesAppPools.ps1
```

```powershell
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
```
