# Unzip Files with WinZip and PowerShell

This PowerShell script will ask for a password and use it to unzip .zipx files from a source directory into a destination directory using WinZip. If the destination directories don't exist, it will create them.

The script works with the following variables:
* `$sourceFolder` : Specifies the path of the source directory.
* `$winZipExe` : Specifies the path of the WinZip executable file.
* `$destinationFolder` : Specifies the path of the destination directory.
* `$passwordCommand` : Stores the command option for the password.


Note: The `Remove-Item` command at the end of the script is currently commented out. If you want the destination folder to be deleted after unzipping, you can uncomment it.
