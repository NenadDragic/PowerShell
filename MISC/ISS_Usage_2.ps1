param (
    [string[]]$ServerNames = @("***", "***", "***")
)

$results = @()

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
