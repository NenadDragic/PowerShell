# Folders Size - FoldersSize.ps1

This script lists the immediate subfolders of a given directory along with their total size (including all nested files), sorted largest first.

## How it works

1. Sets `$folderPath` to the target directory (replace `"C:\Din\Mappe\Sti"` with the actual path).
2. Gets each immediate subfolder via `Get-ChildItem -Directory`, and for each one recursively sums the `Length` of all contained files to get its total size in MB.
3. Sorts the resulting list by size descending and prints it as a table.

## Usage

Edit `$folderPath` before running:

```powershell
.\FoldersSize.ps1
```

```powershell
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
```
