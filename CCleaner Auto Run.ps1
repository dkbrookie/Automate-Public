<#
powershell.exe -command "& {(new-object Net.WebClient).DownloadString('https://goo.gl/RUhMFJ') | iex}
#>

Function Get-Tree($Path,$Include='*'){
    @(Get-Item $Path -Include $Include -Force) +
        (Get-ChildItem $Path -Recurse -Include $Include -Force) | Sort PSPath -Descending -Unique
}

Function Remove-Tree($Path,$Include='*'){
    Get-Tree $Path $Include | Remove-Item -Force -Recurse
}



#region
Write-Output "===CCleaner Auto Clean==="
##Set dir vars
$OS = Get-WMiobject -Class Win32_operatingsystem
$sysDrive = $OS.SystemDrive
$ccleaner = "https://automate.manawa.net/labtech/transfer/software/ccleaner/ccleaner.exe"
$ltPath = "$sysDrive\Windows\LTSvc"
$packagePath = "$ltPath\Packages"
$softwarePath = "$packagePath\Software"
$ccleanerPath = "$softwarePath\CCleaner"
$ccleanerLaunch = "$ccleanerPath\CCleaner.exe"

##Finds C disk space before ccleaner runs
$diskBefore = Get-WmiObject Win32_LogicalDisk | Where {$_.DeviceID -eq $sysDrive}


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
#endregion

##Starts the CCleaner process
Write-Output "Starting Cleaning Process"
Start-Process -FilePath $ccleanerLaunch -ArgumentList "/AUTO"
Wait-Process -Name CCleaner
Write-Output "Cleaning Complete"

##CLear out Windows.old
If(Test-Path "$sysDrive\Windows.old"){
    cmd.exe /c "icacls $sysDrive\Windows.old /grant Everyone:(OI)(CI)F /q"
    cmd.exe /c "takeown /f $sysDrive\Windows.old"
    cmd.exe /c "rd $sysDrive\Windows.old /q /s"
    If(Test-Path "$sysDrive\Windows.old"){
        Write-Output "Removed $sysDrive\Windows.old"
    }
    ELSE{
        Write-Output "Failed to remove $sysDrive\Windows.old"
    }
}

##Clear out the Windows 10 Upgrade folder
If(Test-Path "$sysDrive\Windows10Upgrade"){
    cmd.exe /c "icacls $sysDrive\Windows10Upgrade /grant Everyone:(OI)(CI)F /q"
    cmd.exe /c "takeown /f $sysDrive\Windows10Upgrade"
    Remove-Tree $sysDrive\Windows10Upgrade
    If(Test-Path "$sysDrive\Windows10Upgrade"){
        Write-Output "Removed $sysDrive\Windows10Upgrade"
    }
    ELSE{
        Write-Output "Failed to remove $sysDrive\Windows10Upgrade"
    }
}

##Clear SoftwareDistribution Downloads
If(Test-Path "$sysDrive\Windows\SoftwareDistribution\Downloads"){
    Remove-Tree $sysDrive\Windows\SoftwareDistribution\Downloads
    If(Test-Path "$sysDrive\Windows\SoftwareDistribution\Downloads"){
        Write-Output "Removed $sysDrive\Windows\SoftwareDistribution\Downloads"
    }
    ELSE{
        Write-Output "Failed to remove $sysDrive\Windows10Upgrade"
    }
}

##Gets the free space of C drive intended to use after the clean function to calculate total disk space saved
$diskAfter = Get-WmiObject Win32_LogicalDisk | Where {$_.DeviceID -eq $sysDrive}

##Uses the values from CC-getDiskStart and CC-getDiskEnd to calculate total space saved, then converts it to MBs for easier reading
$before = [math]::Round($diskBefore.FreeSpace/1GB,2)
$after = [math]::Round($diskAfter.FreeSpace/1GB,2)
$saved = [math]::Round([math]::Round($diskAfter.FreeSpace/1MB,2) - [math]::Round($diskBefore.FreeSpace/1MB,2),2)
If($saved -le 0){
    $saved = 0
}

Write-Output "Free Space Before: $before GBs"
Write-Output "Free Space After: $after GBs"
Write-Output "Total Space Saved: $saved MBs"
