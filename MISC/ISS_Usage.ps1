param (
    [string[]]$ServerNames = @("***", "***", "***", "***", "***")
)

$results = @()

foreach ($server in $ServerNames) {
    $result = Invoke-Command -ComputerName $server -ScriptBlock {
        $path = "D:\Webtek"
        $files = Get-ChildItem -Path $path -File -Recurse -Include *.log

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
            ServerName          = $env:COMPUTERNAME
            FolderPath          = $path
            TotalFiles          = $files.Count
            TotalSizeGB         = $totalSizeGB
            DebugFiles          = $debugFiles.Count
            DebugSizeGB         = $debugSizeGB
            DebugSizePercent    = "$debugPercentage%"
            FilesUnder1Month    = $under1Month.Count
            FilesUnder3Months   = $under3Months.Count
            FilesUnder6Months   = $under6Months.Count
            FilesUnder12Months  = $under12Months.Count
            FilesOver1Year      = $over1Year.Count
            DiskSizeGB          = $diskSizeGB
            DiskFreeGB          = $diskFreeGB
            DiskFreePercent     = "$diskFreePercent%"
        }
    }

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

$summary = [PSCustomObject]@{
    ServerName          = "TOTAL"
    TotalFiles          = $totalFiles
    TotalSizeGB         = $totalSizeGB
    DebugFiles          = $totalDebugFiles
    DebugSizeGB         = $totalDebugSizeGB
    DebugSizePercent    = "$totalDebugPercent%"
}

# Vis resultater med diskdata
$results + $summary | Format-Table ServerName, FolderPath, TotalFiles, TotalSizeGB, DebugFiles, DebugSizeGB, DebugSizePercent, FilesUnder1Month, FilesUnder3Months, FilesUnder6Months, FilesUnder12Months, FilesOver1Year, DiskSizeGB, DiskFreeGB, DiskFreePercent -AutoSize
