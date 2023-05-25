$sourceFolder = "N:\Daily"
$winZipExe = "C:\Program Files\WinZip\WZUNZIP.EXE"
$destinationFolder = "c:\UnZipFromN"
$passwordCommand

# Ask the user for a password
$password = Read-Host -Prompt "Please enter the password for the .zipx files"
$passwordCommand = "-s" + $password.ToString()

Get-ChildItem -Path $sourceFolder -Filter *.zipx | ForEach-Object {
    $zipxFile = $_.FullName
    $zipxFileName = $_.BaseName
    $outputFolder = Join-Path -Path $destinationFolder -ChildPath $zipxFileName
    New-Item -ItemType Directory -Path $outputFolder -Force
    & $winZipExe -e -d $passwordCommand $zipxFile $outputFolder

    #Remove-item $outputFolder -r
}
