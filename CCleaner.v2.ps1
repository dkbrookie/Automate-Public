[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Ssl3

## Finds C disk space before cleaning starts
$sysDrive = $env:SystemDrive
$diskBefore = (Get-WmiObject Win32_LogicalDisk).FreeSpace | Measure-Object -Sum

##region fileChecks
$OS = Get-WMiobject -Class Win32_operatingsystem
$ccleanerUrl = "https://drive.google.com/uc?export=download&id=1dK8lqCeu7_iJPKfoXifLjcRPaXDT7N2e"
$ccleanerConfigUrl = "https://drive.google.com/uc?export=download&id=19jwJW41PqApC3tpwSs23ZDbXWN1RUuEt"
$ccleanerDir = "$sysDrive\Windows\LTSvc\packages\Software\CCleaner"
$ccleanerExe = "$ccleanerDir\CCleaner.exe"
$ccleanerIni = "$ccleanerDir\ccleaner.ini"
$logFile = "$sysDrive\Windows\LTSvc\diskCleanup.txt"

If(!(Test-Path $ccleanerDir)) {
  New-Item -Path $ccleanerDir -ItemType Directory | Out-Null
}

Try {
  If ((Test-Path $ccleanerExe -PathType Leaf)) {
    Write-Output 'Ccleaner.exe exists, checking file size...'
    If ((Get-Item $ccleanerExe -EA 0).Length -ne '13594584') {
      Write-Warning 'Ccleaner does exist, but the file size does not match the server. Re-downloading...'
      (New-Object System.Net.WebClient).DownloadFile($ccleanerUrl, $ccleanerExe)
    } Else {
      Write-Output 'Verified Ccleaner.exe file size is correct, executing Ccleaner...'
    }
  } Else {
    Write-Warning 'Ccleaner.exe does not exist, downloading file...'
    (New-Object System.Net.WebClient).DownloadFile($ccleanerUrl, $ccleanerExe)
  }

  If(!(Test-Path $ccleanerIni -PathType Leaf)) {
    (New-Object System.Net.WebClient).DownloadFile($ccleanerConfigUrl, $ccleanerIni)
  }
} Catch {
  Write-Error "!ERROR: Failed to download required files, exiting script"
}
#endregion fileChecks

## Starts the CCleaner process
Try {
  Start-Process -FilePath $ccleanerExe -ArgumentList "/AUTO" -Wait
  Write-Output 'CCleaner complete!'
} Catch {
  Write-Warning '!ERROR: There was a problem running Ccleaner.exe, unable to complete this task'
}

## Deletes old windows update files and old versions of Windows
## Using CMD RD instead of Remove-Item since in the past have had several issues with Remove-Item hanging on
## permission issues instead of skipping and moving on. This is even with trying -Confirm:$False -Force etc.
$folders = "$sysDrive\Windows10Upgrade","$sysDrive\Windows\SoftwareDistribution\Download","$sysDrive\Windows.old"
ForEach($folder in $folders){
  If((Test-Path $folder)){
    &cmd.exe /c echo y| takeown /F $folder\* /R /A /D Y 2>&1 | Out-Null
    &cmd.exe /c echo y| cacls $folder\*.* /T /grant administrators:F 2>&1 | Out-Null
    &cmd.exe /c RD /S /Q $folder | Out-Null
    Write-Output "Deleted $folder"
  }
}

## Deletes temp files
## Using CMD RD instead of Remove-Item for same reasons as above
$folders = "$env:TEMP","$env:SystemDrive\Temp","$env:windir\Temp"
ForEach($folder in $folders){
  If((Test-Path $folder)){
    &cmd.exe /c RD /S /Q $folder 2>&1 | Out-Null
    Write-Output "Deleted temp files from $folder"
  }
}

## Verifies disk cleanup is present, runs it if true
If((Test-Path "$env:windir\System32\cleanmgr.exe" -PathType Leaf)) {
  $diskCleanRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\'
  ## Every item in this long list below is an item on DiskCleanup that will be checked and cleaned through this script
  $cleanItems = 'Active Setup Temp Folders','BranchCache','Content Indexer Cleaner','D3D Shader Cache','Delivery Optimization Files','Device Driver Packages','Diagnostic Data Viewer database files','Downloaded Program Files','DownloadsFolder','Internet Cache Files','Language Pack','Offline Pages Files','Old ChkDsk Files','Previous Installations','Recycle Bin','RetailDemo Offline Content','Service Pack Cleanup','Setup Log Files','System error memory dump files','System error minidump files','System error minidump files','Temporary Setup Files','Thumbnail Cache','Update Cleanup','User file versions','Windows Defender','Windows Error Reporting Files','Windows ESD installation files','Windows Upgrade Log Files'

  ForEach ($item in $cleanItems) {
    $curProperty = Get-ItemProperty -Path "$diskCleanRegPath\$item" -Name StateFlags0777 -EA 0
    If (!$curProperty -or $curProperty.StateFlags0777 -ne 2) {
      Write-Output "Setting $item to enabled in Disk Cleanup"
      New-ItemProperty -Path "$diskCleanRegPath\$item" -Name StateFlags0777 -Value 2 -PropertyType DWORD -EA 0 | Out-Null
    }
  }
  &cmd.exe /c echo y| cleanmgr /sagerun:0777
  Wait-Process cleanmgr
  #Start-Process cleanmgr -ArgumentList "/SAGERUN:0777" -Wait -NoNewWindow
}


<#
WinSxs Cleanup

The /Cleanup-Image parameter of Dism.exe provides advanced users more options to further 
reduce the size of the WinSxS folder. To reduce the amount of space used by a Service 
Pack, use the /SPSuperseded parameter of Dism.exe on a running version of Windows to 
remove any backup components needed for uninstallation of the service pack.
#>
&cmd.exe /c "dism.exe /Online /Cleanup-Image /SPSuperseded" | Out-Null
Write-Output 'DISM service pack cleanup complete'

<#
Using the /ResetBase switch with the /StartComponentCleanup parameter of DISM.exe on a 
running version of Windows removes all superseded versions of every component in the 
## component store
#>
&cmd.exe /c "dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase" | Out-Null
Write-Output 'DISM WinSxs cleanup complete'


## Empty recycle bin
Try {
  $definition = @'
[DllImport("Shell32.dll", CharSet = CharSet.Unicode)]
public static extern uint SHEmptyRecycleBin(IntPtr hwnd, string pszRootPath, uint dwFlags);
'@
  $winApi = Add-Type -MemberDefinition $definition -Name WinAPI -Namespace Extern -PassThru
  $winApi::SHEmptyRecycleBin(0, $null, 7)
  Write-Output 'Recycling bin successfully emptied'
} Catch {
  Write-Warning '!ERROR: There was a problem when attempting to empty the recycling bin, unable to complete this task.'
}


## Gets the free space of C drive after cleaning
$diskAfter = (Get-WmiObject Win32_LogicalDisk).FreeSpace | Measure-Object -Sum

## Uses the values from CC-getDiskStart and CC-getDiskEnd to calculate total space saved, then converts it to MBs for easier reading
$before = [math]::Round($diskBefore.Sum/1MB,2)
$after = [math]::Round($diskAfter.Sum/1MB,2)
$saved = [math]::Round(($before - $after)/1MB,2)
If($saved -le 0){
  $saved = 0
}

## Formats the output so we can split vars in Automate
Write-Output "before=$before|after=$after|spaceSaved=$saved"
