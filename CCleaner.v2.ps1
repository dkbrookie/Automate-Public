[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

## Finds C disk space before cleaning starts
$sysDrive = $env:SystemDrive
$diskBefore = Get-WmiObject Win32_LogicalDisk | Where {$_.DeviceID -eq $sysDrive}

##region fileChecks
$OS = Get-WMiobject -Class Win32_operatingsystem
$ccleanerUrl = "https://drive.google.com/uc?export=download&id=1dK8lqCeu7_iJPKfoXifLjcRPaXDT7N2e"
$ccleanerConfigUrl = "https://drive.google.com/uc?export=download&id=19jwJW41PqApC3tpwSs23ZDbXWN1RUuEt"
$ccleanerDir = "$sysDrive\Windows\LTSvc\packages\Software\CCleaner"
$ccleanerExe = "$ccleanerDir\CCleaner.exe"
$ccleanerIni = "$ccleanerDir\ccleaner.ini"

If(!(Test-Path $ccleanerDir)) {
  New-Item -Path $ccleanerDir -ItemType Directory | Out-Null
}

Try {
  If(!(Test-Path $ccleanerExe -PathType Leaf)) {
    (New-Object System.Net.WebClient).DownloadFile($ccleanerUrl, $ccleanerExe)
    #IWR -Uri $ccleanerUrl -Outfile $ccleanerExe | Out-Null
  }

  If(!(Test-Path $ccleanerIni -PathType Leaf)) {
    (New-Object System.Net.WebClient).DownloadFile($ccleanerConfigUrl, $ccleanerIni)
    #IWR -Uri $ccleanerConfigUrl -Outfile $ccleanerIni | Out-Null
  }
} Catch {
  Write-Error "!ERRDL01: Failed to download required files, exiting script"
}
#endregion fileChecks

## Starts the CCleaner process
Start-Process -FilePath $ccleanerExe -ArgumentList "/AUTO"
Wait-Process -Name CCleaner

## Deletes unneeded files
$folders = "$sysDrive\Windows10Upgrade","$sysDrive\Windows\SoftwareDistribution\Downloads","$sysDrive\Windows.old"
ForEach($folder in $folders){
    If(Test-Path $folder){
        echo y| takeown /F $sysDrive\Windows.old\* /R /A /D Y | Out-Null
        echo y| cacls $sysDrive\Windows.old\*.* /T /grant administrators:F | Out-Null
        cmd.exe /c "RD /S /Q $folder/" | Out-Null
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
      } Else {
          Write-Output "Confirmed $item is enabled in Disk Cleanup"
      }
  }
  Start-Process cleanmgr -ArgumentList "/SAGERUN:777" -Wait -NoNewWindow
}


<#
WinSxs Cleanup

The /Cleanup-Image parameter of Dism.exe provides advanced users more options to further 
reduce the size of the WinSxS folder. To reduce the amount of space used by a Service 
Pack, use the /SPSuperseded parameter of Dism.exe on a running version of Windows to 
remove any backup components needed for uninstallation of the service pack.
#>
&cmd.exe /c "dism.exe /Online /Cleanup-Image /SPSuperseded"

<#
Using the /ResetBase switch with the /StartComponentCleanup parameter of DISM.exe on a 
running version of Windows removes all superseded versions of every component in the 
## component store
#>
&cmd.exe /c "dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase"


## Empty recycle bin
$definition = @'
[DllImport("Shell32.dll", CharSet = CharSet.Unicode)]
public static extern uint SHEmptyRecycleBin(IntPtr hwnd, string pszRootPath, uint dwFlags);
'@
$winApi = Add-Type -MemberDefinition $definition -Name WinAPI -Namespace Extern -PassThru
$winApi::SHEmptyRecycleBin(0, $null, 7)

## Empty out all of the temp folders
$tempFolders = "$env:TEMP\*","$env:SystemDrive\Temp\*","$env:windir\Temp\*"
ForEach ($tempFolder in $tempFolders) {
    Remove-Item -Path $tempFolder -Recurse -Force -EA 0
}


## Gets the free space of C drive after cleaning
$diskAfter = Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DeviceID -eq $sysDrive}

## Uses the values from CC-getDiskStart and CC-getDiskEnd to calculate total space saved, then converts it to MBs for easier reading
$before = [math]::Round($diskBefore.FreeSpace/1GB,2)
$after = [math]::Round($diskAfter.FreeSpace/1GB,2)
$saved = [math]::Round([math]::Round($diskAfter.FreeSpace/1MB,2) - [math]::Round($diskBefore.FreeSpace/1MB,2),2)
If($saved -le 0){
    $saved = 0
}

## Formats the output so we can split vars in Automate
Write-Output "before=$before|after=$after|spaceSaved=$saved"
