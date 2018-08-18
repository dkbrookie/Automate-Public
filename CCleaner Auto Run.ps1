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

Function CC-getDiskStart{
    ##Finds C disk space before ccleaner runs
    $diskBefore = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskBefore = $diskBefore.FreeSpace
}

Function CC-fileCheck{
    ##Verifies that all needed dirs and files are in place
    $diskBefore = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskBefore = $diskBefore.FreeSpace

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
}

Function CC-cleanAuto{
    ##Starts the CCleaner process
    Start-Process -FilePath $ccleanerLaunch -ArgumentList "/AUTO"
}

Function CC-getDiskEnd{
    ##Gets the free space of C drive intended to use after the clean function to calculate total disk space saved
    $diskAfter = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskAfter = $diskAfter.FreeSpace
}

Function CC-calcSaved{
    ##Uses the values from CC-getDiskStart and CC-getDiskEnd to calculate total space saved, then converts it to MBs for easier reading
    $saved = $diskBefore - $diskAfter
    $saved = $saved / 1024 / 1024
    $saved = ($saved).ToString("#.##")
    Write-Output "Saved $saved MBs"
}

CC-getDiskStart
CC-fileCheck
CC-cleanAuto
CC-getDiskEnd
CC-calcSaved
