param (
    [int]$months = 1 # Default value for months
)

# Gets the size of every directory under the $startDirectory directory
# Can sometimes be a little slow if a directory has a lot of folders in it
$startDirectory = 'D:\'
$outputDirectory = 'C:\Temp\' # Change this to your desired output directory

# Gets the machine name
$machineName = $env:COMPUTERNAME

# Gets a list of folders under the $startDirectory directory
$directoryItems = Get-ChildItem $startDirectory -Recurse | Where-Object {$_.PSIsContainer -eq $true} | Sort-Object

# Creates an array to store the results
$results = @()

# Initialize total counters
$totalLogFileCount = 0
$totalOldFileCount = 0
$totalSizeGB = 0
$totalOldFileSizeGB = 0

# Loops through the list, calculating the size of each directory
foreach ($i in $directoryItems) {
    $logFiles = Get-ChildItem $i.FullName -Recurse -Force -Filter *.log | Where-Object {$_.PSIsContainer -eq $false}
    $fileCount = $logFiles.Count
    $sizeInGB = [math]::Round(($logFiles | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
    if ($sizeInGB -gt 0) {
        $oldestFile = $logFiles | Sort-Object CreationTime | Select-Object -First 1
        $newestFile = $logFiles | Sort-Object CreationTime -Descending | Select-Object -First 1
        $isOldFile = (New-TimeSpan -Start $oldestFile.CreationTime -End (Get-Date)).Days -gt ($months * 30)
        
        # Calculate files and size over specified months old
        $oldFiles = $logFiles | Where-Object { (New-TimeSpan -Start $_.CreationTime -End (Get-Date)).Days -gt ($months * 30) }
        $oldFileCount = $oldFiles.Count
        $oldFileSizeInGB = [math]::Round(($oldFiles | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
        
        # Update total counters
        $totalLogFileCount += $fileCount
        $totalOldFileCount += $oldFileCount
        $totalSizeGB += $sizeInGB
        $totalOldFileSizeGB += $oldFileSizeInGB
        
        $results += [PSCustomObject]@{
            Directory = $i.FullName
            SizeGB = $sizeInGB
            FileCount = $fileCount
            OldestFileDate = $oldestFile.CreationTime
            NewestFileDate = $newestFile.CreationTime
            OldFileCheckmark = if ($isOldFile) { "✔️" } else { "" }
            OldFileCount = $oldFileCount
            OldFileSizeGB = $oldFileSizeInGB
        }
    }
}

# Outputs the results in a table format
$results | Format-Table -AutoSize

# Outputs the total summary
$totalSummary = @"
Total Log Files: $totalLogFileCount
Total Old Files (over $months months): $totalOldFileCount
Total Size of All Files: $([math]::Round($totalSizeGB, 2)) GB
Total Size of Old Files: $([math]::Round($totalOldFileSizeGB, 2)) GB
"@

# Combine results and summary
$output = $results | Format-Table -AutoSize | Out-String
$output += $totalSummary

# Save to file
$outputFilePath = Join-Path $outputDirectory "$machineName.txt"
$output | Out-File -FilePath $outputFilePath

# Outputs the total summary to screen
Write-Host "Total Log Files: $totalLogFileCount"
Write-Host "Total Old Files (over $months months): $totalOldFileCount"
Write-Host "Total Size of All Files: $([math]::Round($totalSizeGB, 2)) GB"
Write-Host "Total Size of Old Files: $([math]::Round($totalOldFileSizeGB, 2)) GB"
