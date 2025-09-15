$folderPath = "C:\Din\Mappe\Sti"

# Hent alle undermapper og beregn størrelse
$folders = Get-ChildItem -Path $folderPath -Directory | ForEach-Object {
    $size = (Get-ChildItem -Path $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    [PSCustomObject]@{
        Folder = $_.FullName
        SizeMB = [math]::Round($size / 1MB, 2)
    }
}

# Sorter efter størrelse og vis
$folders | Sort-Object SizeMB -Descending | Format-Table -AutoSize
