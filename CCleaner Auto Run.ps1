<#
powershell.exe -command "& {(new-object Net.WebClient).DownloadString('https://goo.gl/RUhMFJ') | iex}
#>

##Finds C disk space before cleaning starts
$sysDrive = $env:SystemDrive
$diskBefore = Get-WmiObject Win32_LogicalDisk | Where {$_.DeviceID -eq $sysDrive}

Function Get-Tree($Path,$Include='*'){
    @(Get-Item $Path -Include $Include -Force) +
        (Get-ChildItem $Path -Recurse -Include $Include -Force) | Sort PSPath -Descending -Unique
}

Function Remove-Tree($Path,$Include='*'){
    Get-Tree $Path $Include | Remove-Item -Force -Recurse
}

Function CC-fileCheck{
    Write-Output "===CCleaner File Check==="
    ##Set dir vars
    $OS = Get-WMiobject -Class Win32_operatingsystem
    $ccleaner = "https://automate.manawa.net/labtech/transfer/software/ccleaner/ccleaner.exe"
    $ltPath = "$sysDrive\Windows\LTSvc"
    $packagePath = "$ltPath\Packages"
    $softwarePath = "$packagePath\Software"
    $ccleanerPath = "$softwarePath\CCleaner"
    $script:ccleanerLaunch = "$ccleanerPath\CCleaner.exe"

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

Function CC-startClean{
    ##Starts the CCleaner process
    Write-Output "===CCleaner Started==="
    Start-Process -FilePath $script:ccleanerLaunch -ArgumentList "/AUTO"
    Wait-Process -Name CCleaner
    Write-Output "Cleaning Complete"
}

Function CC-calcSaved{
    Write-Output "===Calculating Space Saved==="
    ##Uses the values from CC-getDiskStart and CC-getDiskEnd to calculate total space saved, then converts it to MBs for easier reading
    $script:before = [math]::Round($diskBefore.FreeSpace/1GB,2)
    $script:after = [math]::Round($diskAfter.FreeSpace/1GB,2)
    $script:saved = [math]::Round([math]::Round($diskAfter.FreeSpace/1MB,2) - [math]::Round($diskBefore.FreeSpace/1MB,2),2)
    If($saved -le 0){
        $script:saved = 0
    }

}

Function DC-removeDirs{
    $folders = "$sysDrive\Windows10Upgrade","$sysDrive\Windows\SoftwareDistribution\Downloads","$sysDrive\Windows.old"
    ForEach($folder in $folders){
        If(Test-Path $folder){
            Write-Output "Attempting to delete $folder"
            cmd.exe /c "takeown /F $sysDrive\Windows.old\* /R /A" | Out-Null
            cmd.exe /c "cacls $sysDrive\Windows.old\*.* /T /grant administrators:F" | Out-Null
            Remove-Tree $folder
            If(Test-Path $folder){
                Write-Output "Failed to delete $folder"
            }
            Else{
                Write-Output "Successfully deleted $folder"
            }
        }
        Else{
            Write-Output "Confirmed $folder doesn't exist"
        }
    }
}

Function DC-diskClean{
    Start-Process cleanmgr -ArgumentList "/AUTOCLEAN" -Wait -NoNewWindow -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
}

CC-fileCheck
CC-startClean
DC-diskClean

##Gets the free space of C drive after cleaning
$diskAfter = Get-WmiObject Win32_LogicalDisk | Where {$_.DeviceID -eq $sysDrive}

cc-calcSaved

Write-Output "Free Space Before: $before GBs"
Write-Output "Free Space After: $after GBs"
Write-Output "Total Space Saved: $saved MBs"
