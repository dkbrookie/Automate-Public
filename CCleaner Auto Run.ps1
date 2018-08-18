<#
powershell.exe -command "& {(new-object Net.WebClient).DownloadString('https://goo.gl/RUhMFJ') | iex}
#>

##Set dir vars
$ccleaner = "https://automate.manawa.net/labtech/transfer/software/ccleaner/ccleaner.exe"
$ltPath = "C:\Windows\LTSvc"
$packagePath = "$ltPath\Packages"
$softwarePath = "$packagePath\Software"
$ccleanerPath = "$softwarePath\CCleaner"
$ccleanerLaunch = "$ccleanerPath\CCleaner.exe"


Try{
    ##Finds C disk space before ccleaner runs
    $diskBefore = Get-WmiObject Win32_LogicalDisk | Where {$_.DeviceID -eq "C:"}
}
Catch{
    Write-Warning "Failed to get disk space $_.Exception.Message"
}


$packageTest = Test-Path $packagePath
If(!$packageTest){
    New-Item -ItemType Directory -Path "$packagePath"
    Write-Output "Packages folder missing, created the folder $packagePath"
}

$softwareTest = Test-Path $softwarePath
If(!$packageTest){
    New-Item -ItemType Directory -Path "$softwarePath"
    Write-Output "Software folder missing, created the folder $softwarePath"
}

$ccleanerTest = Test-Path $ccleanerPath
If(!$ccleanerTest){
    New-Item -ItemType Directory -Path "$ccleanerPath"
    Write-Output "CCleaner folder missing, created the folder $ccleanerePath"
}

$downloadStatus = Test-Path "$ccleanerPath\ccleaner.exe" -PathType Leaf
If(!$downloadStatus){
    IWR -Uri $ccleaner -Outfile $ccleanerPath\ccleaner.exe
    Write-Output "No CCleaner.exe found in $ccleanerpath, downloaded CCleaner.exe"
    $downloadStatus = Test-Path "$ccleanerPath\ccleaner.exe" -PathType Leaf
    If(!$downloadStatus){
        Write-Output "!ERRDL01: Failed to download CCleaner.exe from $ccleaner, exiting script"
        Break
    }
}
Else{
    Write-Output "Verified CCleaner.exe exists at $ccleanerPath"
}


##Starts the CCleaner process
Write-Output "Starting Cleaning Process"
Start-Process -FilePath $ccleanerLaunch -ArgumentList "/AUTO"
Wait-Process -Name CCleaner
Write-Output "Cleaning Complete"

##Gets the free space of C drive intended to use after the clean function to calculate total disk space saved
$diskAfter = Get-WmiObject Win32_LogicalDisk | Where {$_.DeviceID -eq "C:"}

##Uses the values from CC-getDiskStart and CC-getDiskEnd to calculate total space saved, then converts it to MBs for easier reading
$before = $diskBefore.FreeSpace
$after = $diskAfter.FreeSpace
$saved = [math]::Round([math]::Round($before/1MB,2) - [math]::Round($after/1MB,2),2)
Write-Output "Free Space Before: $before"
Write-Output "Free Space After: $after"
Write-Output "Total Space Saved: $saved MBs"
