# IIS Log Usage Report v2 - ISS_Usage_2.ps1

This script scans `D:\` on a list of servers for log-type files, reports total and debug-related file counts/sizes broken down by age bucket (under 1/3/6/12 months, over 1 year), and exports the results to CSV. Same logic as the JB-Scripts `IIS_Log_Test.ps1`/`IIS_Log_Prod.ps1` scripts, with placeholder server names and no CSV path set by default.

## How it works

1. Accepts `-ServerNames` (defaults to a placeholder list of 3 server names — replace before use). `$csvPath` is empty by default and must be set before running, or the `Export-Csv` calls will fail.
2. For each server, runs a remote script block via `Invoke-Command` that:
   - Finds all files under `D:\` matching common log/backup extensions.
   - Flags files as "debug" if they contain any of `TRACE`, `DEBUG`, `EXCEPTION`, `STACKTRACE`, or `Failed Request`.
   - Buckets files by age: under 1 month, 1–3 months, 3–6 months, 6–12 months, and over 1 year, with count and size (GB) per bucket.
   - Computes total and debug-only file counts/sizes, the debug percentage, and `D:` drive size/free space.
3. Prints a per-server table and appends each server's result to the CSV.
4. Prints a final summary table totaling all metrics across servers.

## Usage

Set `$csvPath` to a real output path before running:

```powershell
.\ISS_Usage_2.ps1 -ServerNames "Server1","Server2"
```

```powershell
param (
    [string[]]$ServerNames = @("***", "***", "***")
)

$results = @()

# Define the output CSV file path
$csvPath = ""

# Remove the old file if it exists, so headers are written fresh
if (Test-Path $csvPath) {
    Remove-Item $csvPath -Force
}

Write-Host "`n--- Servervise resultater ---`n"

foreach ($server in $ServerNames) {
    $result = Invoke-Command -ComputerName $server -ScriptBlock {
        $path = "D:\"
        $patterns = @("*.log", "*.txt", "*.out", "*.err", "*.log.*", "*.log.*.gz", "*.log.*.zip", "*.log.old", "*.bak")
        $files = @()

        foreach ($pattern in $patterns) {
            $files += Get-ChildItem -Path $path -File -Recurse -Include $pattern -ErrorAction SilentlyContinue
        }

        $debugKeywords = @("TRACE", "DEBUG", "EXCEPTION", "STACKTRACE", "Failed Request")
        $debugFiles = @()

        foreach ($file in $files) {
            foreach ($keyword in $debugKeywords) {
                if (Select-String -Path $file.FullName -Pattern $keyword -Quiet) {
                    $debugFiles += $file
                    break
                }
            }
        }

        $now = Get-Date
        $under1Month    = $files | Where-Object { $_.LastWriteTime -gt $now.AddMonths(-1) }
        $under3Months   = $files | Where-Object { $_.LastWriteTime -le $now.AddMonths(-1) -and $_.LastWriteTime -gt $now.AddMonths(-3) }
        $under6Months   = $files | Where-Object { $_.LastWriteTime -le $now.AddMonths(-3) -and $_.LastWriteTime -gt $now.AddMonths(-6) }
        $under12Months  = $files | Where-Object { $_.LastWriteTime -le $now.AddMonths(-6) -and $_.LastWriteTime -gt $now.AddYears(-1) }
        $over1Year      = $files | Where-Object { $_.LastWriteTime -lt $now.AddYears(-1) }

        $under1MonthSizeGB   = [math]::Round((($under1Month   | Measure-Object -Property Length -Sum).Sum) / 1GB, 2)
        $under3MonthsSizeGB  = [math]::Round((($under3Months  | Measure-Object -Property Length -Sum).Sum) / 1GB, 2)
        $under6MonthsSizeGB  = [math]::Round((($under6Months  | Measure-Object -Property Length -Sum).Sum) / 1GB, 2)
        $under12MonthsSizeGB = [math]::Round((($under12Months | Measure-Object -Property Length -Sum).Sum) / 1GB, 2)
        $over1YearSizeGB     = [math]::Round((($over1Year     | Measure-Object -Property Length -Sum).Sum) / 1GB, 2)

        $totalSizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
        $debugSizeBytes = ($debugFiles | Measure-Object -Property Length -Sum).Sum

        $totalSizeGB = [math]::Round($totalSizeBytes / 1GB, 2)
        $debugSizeGB = [math]::Round($debugSizeBytes / 1GB, 2)
        $debugPercentage = if ($totalSizeBytes -gt 0) {
            [math]::Round(($debugSizeBytes / $totalSizeBytes) * 100, 2)
        } else {
            0
        }

        # Disk info for D:
        $disk = Get-PSDrive -Name D
        $diskSizeGB = [math]::Round(($disk.Used + $disk.Free) / 1GB, 2)
        $diskFreeGB = [math]::Round($disk.Free / 1GB, 2)
        $diskFreePercent = if ($diskSizeGB -gt 0) {
            [math]::Round(($diskFreeGB / $diskSizeGB) * 100, 2)
        } else {
            0
        }

        [PSCustomObject]@{
            ServerName            = $env:COMPUTERNAME
            FolderPath            = $path
            TotalFiles            = $files.Count
            TotalSizeGB           = $totalSizeGB
            DebugFiles            = $debugFiles.Count
            DebugSizeGB           = $debugSizeGB
            DebugSizePercent      = "$debugPercentage%"
            FilesUnder1Month      = $under1Month.Count
            FilesUnder1MonthGB    = $under1MonthSizeGB
            FilesUnder3Months     = $under3Months.Count
            FilesUnder3MonthsGB   = $under3MonthsSizeGB
            FilesUnder6Months     = $under6Months.Count
            FilesUnder6MonthsGB   = $under6MonthsSizeGB
            FilesUnder12Months    = $under12Months.Count
            FilesUnder12MonthsGB  = $under12MonthsSizeGB
            FilesOver1Year        = $over1Year.Count
            FilesOver1YearGB      = $over1YearSizeGB
            DiskSizeGB            = $diskSizeGB
            DiskFreeGB            = $diskFreeGB
            DiskFreePercent       = "$diskFreePercent%"
        }
    }

    # Print resultatet for serveren med tabel-format
    $result | Format-Table ServerName, FolderPath, TotalFiles, TotalSizeGB, DebugFiles, DebugSizeGB, DebugSizePercent, `
        FilesUnder1Month, FilesUnder1MonthGB, FilesUnder3Months, FilesUnder3MonthsGB, FilesUnder6Months, FilesUnder6MonthsGB, `
        FilesUnder12Months, FilesUnder12MonthsGB, FilesOver1Year, FilesOver1YearGB, DiskSizeGB, DiskFreeGB, DiskFreePercent -AutoSize
    Write-Host ""

    $results += $result

    # Save current result line to CSV (append after first write)
    if ((Get-Item $csvPath -ErrorAction SilentlyContinue) -eq $null) {
        $result | Export-Csv -Path $csvPath -NoTypeInformation
    } else {
        $result | Export-Csv -Path $csvPath -NoTypeInformation -Append
    }
}

# Fælles summering
$totalFiles = ($results | Measure-Object -Property TotalFiles -Sum).Sum
$totalSizeGB = ($results | Measure-Object -Property TotalSizeGB -Sum).Sum
$totalDebugFiles = ($results | Measure-Object -Property DebugFiles -Sum).Sum
$totalDebugSizeGB = ($results | Measure-Object -Property DebugSizeGB -Sum).Sum
$totalDebugPercent = if ($totalSizeGB -gt 0) {
    [math]::Round(($totalDebugSizeGB / $totalSizeGB) * 100, 2)
} else {
    0
}

$totalFilesUnder1Month     = ($results | Measure-Object -Property FilesUnder1Month -Sum).Sum
$totalFilesUnder1MonthGB   = ($results | Measure-Object -Property FilesUnder1MonthGB -Sum).Sum
$totalFilesUnder3Months    = ($results | Measure-Object -Property FilesUnder3Months -Sum).Sum
$totalFilesUnder3MonthsGB  = ($results | Measure-Object -Property FilesUnder3MonthsGB -Sum).Sum
$totalFilesUnder6Months    = ($results | Measure-Object -Property FilesUnder6Months -Sum).Sum
$totalFilesUnder6MonthsGB  = ($results | Measure-Object -Property FilesUnder6MonthsGB -Sum).Sum
$totalFilesUnder12Months   = ($results | Measure-Object -Property FilesUnder12Months -Sum).Sum
$totalFilesUnder12MonthsGB = ($results | Measure-Object -Property FilesUnder12MonthsGB -Sum).Sum
$totalFilesOver1Year       = ($results | Measure-Object -Property FilesOver1Year -Sum).Sum
$totalFilesOver1YearGB     = ($results | Measure-Object -Property FilesOver1YearGB -Sum).Sum

$summary = [PSCustomObject]@{
    ServerName           = "TOTAL"
    TotalFiles           = $totalFiles
    TotalSizeGB          = $totalSizeGB
    DebugFiles           = $totalDebugFiles
    DebugSizeGB          = $totalDebugSizeGB
    DebugSizePercent     = "$totalDebugPercent%"
    FilesUnder1Month     = $totalFilesUnder1Month
    FilesUnder1MonthGB   = $totalFilesUnder1MonthGB
    FilesUnder3Months    = $totalFilesUnder3Months
    FilesUnder3MonthsGB  = $totalFilesUnder3MonthsGB
    FilesUnder6Months    = $totalFilesUnder6Months
    FilesUnder6MonthsGB  = $totalFilesUnder6MonthsGB
    FilesUnder12Months   = $totalFilesUnder12Months
    FilesUnder12MonthsGB = $totalFilesUnder12MonthsGB
    FilesOver1Year       = $totalFilesOver1Year
    FilesOver1YearGB     = $totalFilesOver1YearGB
}

# Print kun summering til sidst
Write-Host "`n--- Samlet summering ---`n"
$summary | Format-Table ServerName, TotalFiles, TotalSizeGB, DebugFiles, DebugSizeGB, DebugSizePercent, `
    FilesUnder1Month, FilesUnder1MonthGB, FilesUnder3Months, FilesUnder3MonthsGB, FilesUnder6Months, FilesUnder6MonthsGB, `
    FilesUnder12Months, FilesUnder12MonthsGB, FilesOver1Year, FilesOver1YearGB -AutoSize
```
