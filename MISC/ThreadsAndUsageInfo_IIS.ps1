Import-Module WebAdministration

# Fastfrys dato/tid og maskinenavn for hele udtrækket
$now        = Get-Date
$dateStr    = $now.ToString('yyyy-MM-dd')     # Kolonne: Date
$timeStr    = $now.ToString('HH:mm:ss')       # Kolonne: Time
$fileStamp  = $now.ToString('yyyy-MM-dd_HH_mm')  # Filnavn: YYYY-MM-DD_HH_MM
$computer   = $env:COMPUTERNAME

# (Valgfrit) mappe til output – ret denne hvis du vil gemme et andet sted
$outDir   = "C:\Temp\w3wp-logs"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$csvPath  = Join-Path $outDir ("w3wp_overview_{0}.csv" -f $fileStamp)

# Hent alle w3wp-processer
$w3wpProcesses = Get-WmiObject Win32_Process | Where-Object { $_.Name -eq "w3wp.exe" }
$total   = $w3wpProcesses.Count
$counter = 0

# Hent site-info én gang
$siteInfo = Get-WebConfiguration "/system.applicationHost/sites/site" | ForEach-Object {
    $siteName = $_.Attributes["name"].Value
    $appPool  = $_.ChildElements["application"].Attributes["applicationPool"].Value
    [PSCustomObject]@{
        SiteName = $siteName
        AppPool  = $appPool
    }
}

$results = @()

foreach ($proc in $w3wpProcesses) {
    $counter++
    Write-Host "Behandler proces $counter af $total..." -ForegroundColor DarkGray
    $cmdLine = $proc.CommandLine

    if ($cmdLine -match '-ap\s+"([^"]+)"') {
        $appPoolName = $matches[1]
        $memMB  = [math]::Round($proc.WorkingSetSize / 1MB, 2)
        $procId = $proc.ProcessId

        # Hent brugernavn
        $ownerInfo = $proc.GetOwner()
        $userName = "$($ownerInfo.Domain)\$($ownerInfo.User)"

        # Hent Threads / Handles / CPU via Get-Process, med fallback til WMI
        $threadCount = $null
        $handleCount = $null
        $cpuTimeText = $null  # formateret CPU-tid (d.hh:mm:ss eller hh:mm:ss)

        try {
            $psProc = Get-Process -Id $procId -ErrorAction Stop
            $threadCount = $psProc.Threads.Count
            $handleCount = $psProc.HandleCount

            # TotalProcessorTime er en TimeSpan
            if ($psProc.TotalProcessorTime) {
                $cpuTimeText = $psProc.TotalProcessorTime.ToString()
            } elseif ($psProc.CPU -ne $null) {
                $cpuTimeText = [TimeSpan]::FromSeconds([double]$psProc.CPU).ToString()
            }
        } catch {
            # Fallbacks via WMI-egenskaber
            if ($proc.PSObject.Properties.Name -contains 'ThreadCount') {
                $threadCount = [int]$proc.ThreadCount
            }
            if ($proc.PSObject.Properties.Name -contains 'HandleCount') {
                $handleCount = [int]$proc.HandleCount
            }
            # CPU via WMI KernelModeTime + UserModeTime (100 ns = .NET ticks)
            if ($proc.PSObject.Properties.Name -contains 'KernelModeTime' -and
                $proc.PSObject.Properties.Name -contains 'UserModeTime' -and
                $null -ne $proc.KernelModeTime -and $null -ne $proc.UserModeTime) {
                try {
                    $totalTicks = [int64]$proc.KernelModeTime + [int64]$proc.UserModeTime
                    $cpuTimeText = [TimeSpan]::FromTicks($totalTicks).ToString()
                } catch { }
            }
        }

        # Find sites der bruger denne AppPool
        $sites = $siteInfo | Where-Object { $_.AppPool -eq $appPoolName } | Select-Object -ExpandProperty SiteName
        $siteList = if ($sites) { $sites -join ", " } else { "Ukendt" }

        # Resultatobjekt med ønsket kolonnerækkefølge (Dato, Tid, Computer først)
        $results += [PSCustomObject]@{
            Date      = $dateStr
            Time      = $timeStr
            Computer  = $computer
            AppPool   = $appPoolName
            Sites     = $siteList
            PID       = $procId
            Threads   = $threadCount
            Handles   = $handleCount
            CPUTime   = $cpuTimeText
            MemoryMB  = $memMB
            User      = $userName
        }
    }
}

# Sørg for ensartet kolonne-rækkefølge og gem til CSV med ønsket navngivning
$ordered = $results |
    Select-Object Date, Time, Computer, AppPool, Sites, PID, Threads, Handles, CPUTime, MemoryMB, User

# Brug -UseCulture så CSV bruger systemets listesep. (typisk semikolon på da-DK) og spiller bedre med Excel
$ordered | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -UseCulture

Write-Host "CSV gemt: $csvPath" -ForegroundColor Green

# (Valgfrit) også vis i konsollen i samme rækkefølge
$ordered | Format-Table -AutoSize
