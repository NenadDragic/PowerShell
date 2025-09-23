# >>> UDFYLD SERVERLISTEN HER <<<
$Servers = @("","")  # Skriv maskinnavne her

# (Valgfrit) Brug alternative credentials
$UseCredential = $false
if ($UseCredential) { $Cred = Get-Credential }

# Lokal output-mappe (på din maskine)
$outDir = "C:\Temp\w3wp-logs"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# Fælles tidsstempel for hele kørsel (samme på tværs af servere)
$now       = Get-Date
$fileStamp = $now.ToString('yyyy-MM-dd_HH_mm')

$allResults = @()

foreach ($srv in $Servers) {
    try {
        $sb = {
            param($now)

            # Importér IIS-modul hvis tilgængeligt
            try { Import-Module WebAdministration -ErrorAction Stop } catch {}

            # Fastfrys dato/tid og maskinenavn for hele udtrækket (pr. server)
            $dateStr   = $now.ToString('yyyy-MM-dd')        # Kolonne: Date
            $timeStr   = $now.ToString('HH:mm:ss')          # Kolonne: Time
            $computer  = $env:COMPUTERNAME

            # Hent alle w3wp-processer
            $w3wpProcesses = Get-WmiObject Win32_Process | Where-Object { $_.Name -eq "w3wp.exe" }

            # Hent site-info hvis WebAdministration er tilgængelig
            $siteInfo = @()
            if (Get-Module -ListAvailable -Name WebAdministration) {
                try {
                    $siteInfo = Get-WebConfiguration "/system.applicationHost/sites/site" | ForEach-Object {
                        $siteName = $_.Attributes["name"].Value
                        $appPool  = $_.ChildElements["application"].Attributes["applicationPool"].Value
                        [PSCustomObject]@{
                            SiteName = $siteName
                            AppPool  = $appPool
                        }
                    }
                } catch { }
            }

            $results = @()

            foreach ($proc in $w3wpProcesses) {
                $cmdLine = $proc.CommandLine

                if ($cmdLine -match '-ap\s+"([^"]+)"') {
                    $appPoolName = $matches[1]
                    $memMB  = [math]::Round($proc.WorkingSetSize / 1MB, 2)
                    $procId = $proc.ProcessId

                    # Hent brugernavn
                    $userName = $null
                    try {
                        $ownerInfo = $proc.GetOwner()
                        if ($ownerInfo.ReturnValue -eq 0) {
                            $userName = "$($ownerInfo.Domain)\$($ownerInfo.User)"
                        }
                    } catch { }

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
                    $sites = @()
                    if ($siteInfo) {
                        $sites = $siteInfo |
                            Where-Object { $_.AppPool -eq $appPoolName } |
                            Select-Object -ExpandProperty SiteName
                    }
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

            # Returnér med fast kolonnerækkefølge
            $results | Select-Object Date, Time, Computer, AppPool, Sites, PID, Threads, Handles, CPUTime, MemoryMB, User
        }

        # Kald fjernmaskinen
        if ($UseCredential) {
            $serverResults = Invoke-Command -ComputerName $srv -ScriptBlock $sb -ArgumentList $now -Credential $Cred -ErrorAction Stop
        } else {
            $serverResults = Invoke-Command -ComputerName $srv -ScriptBlock $sb -ArgumentList $now -ErrorAction Stop
        }

        # Gem én CSV pr. server på lokal maskine
        $computerSafe = ($srv -replace '[\\/:*?"<>|]', '_')    # sikkerhed for evt. ulovlige tegn
        $csvPath      = Join-Path $outDir ("{0}_{1}.csv" -f $computerSafe, $fileStamp)
        $serverResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -UseCulture
        Write-Host "[$srv] CSV gemt: $csvPath" -ForegroundColor Green

        # Saml resultater (kan bruges til samlet fil eller visning)
        $allResults += $serverResults
    } catch {
        Write-Warning "[$srv] Fejl: $($_.Exception.Message)"
    }
}

# (Valgfrit) Samlet CSV på tværs af alle servere
# $combinedPath = Join-Path $outDir ("ALL_{0}.csv" -f $fileStamp)
# $allResults | Export-Csv -Path $combinedPath -NoTypeInformation -Encoding UTF8 -UseCulture
# Write-Host "Samlet CSV gemt: $combinedPath" -ForegroundColor Cyan

# (Valgfrit) Vis i konsollen i samme rækkefølge
$allResults | Format-Table -AutoSize
