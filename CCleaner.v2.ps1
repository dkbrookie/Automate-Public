## Finds C disk space before cleaning starts
$sysDrive = $env:SystemDrive
$diskBefore = Get-WmiObject Win32_LogicalDisk | Where {$_.DeviceID -eq $sysDrive}

##region fileChecks
$OS = Get-WMiobject -Class Win32_operatingsystem
$ccleanerUrl = "https://automate.manawa.net/labtech/transfer/software/ccleaner/ccleaner.exe"
$ccleanerConfigUrl = "https://automate.manawa.net/labtech/transfer/software/ccleaner/ccleaner.ini"
$ccleanerDir = "$sysDrive\Windows\LTSvc\packages\Software\CCleaner"
$ccleanerExe = "$ccleanerDir\CCleaner.exe"
$ccleanerIni = "$ccleanerDir\ccleaner.ini"

If(!(Test-Path $ccleanerDir)) {
  New-Item -Path $ccleanerDir -ItemType Directory | Out-Null
}

Try {
  If(!(Test-Path $ccleanerExe -PathType Leaf)) {
    IWR -Uri $ccleanerUrl -Outfile $ccleanerExe | Out-Null
  }

  If(!(Test-Path $ccleanerIni -PathType Leaf)) {
    IWR -Uri $ccleanerConfigUrl -Outfile $ccleanerIni | Out-Null
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
If((Test-Path "$sysDrive\Windows\System32\)cleamngr.exe" -PathType Leaf)) {
  Start-Process cleanmgr -ArgumentList "/AUTOCLEAN" -Wait -NoNewWindow -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
}

## Gets the free space of C drive after cleaning
$diskAfter = Get-WmiObject Win32_LogicalDisk | Where {$_.DeviceID -eq $sysDrive}

## Uses the values from CC-getDiskStart and CC-getDiskEnd to calculate total space saved, then converts it to MBs for easier reading
$before = [math]::Round($diskBefore.FreeSpace/1GB,2)
$after = [math]::Round($diskAfter.FreeSpace/1GB,2)
$saved = [math]::Round([math]::Round($diskAfter.FreeSpace/1MB,2) - [math]::Round($diskBefore.FreeSpace/1MB,2),2)
If($saved -le 0){
    $saved = 0
}

## Formats the output so we can split vars in Automate
Write-Output "before=$before|after=$after|saved=$saved"
