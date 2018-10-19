Function Get-Tree($Path,$Include='*'){
    @(Get-Item $Path -Include $Include -Force) +
        (Get-ChildItem $Path -Recurse -Include $Include -Force) | Sort PSPath -Descending -Unique
}

Function Remove-Tree($Path,$Include='*'){
    Get-Tree $Path $Include | Remove-Item -Force -Recurse
}

$ltServFile = '3927745135'
$checkFile = Test-Path 'C:\Windows\LTSvc\Packages\OS\Win10x64.1803\Prox64.1803.zip' -PathType Leaf

If($checkFile){
    $clientFile = Get-Item 'C:\Windows\LTSvc\Packages\OS\Win10x64.1803\Prox64.1803.zip'
    If($ltServFile -gt $clientFile.Length){
        Write-Output "ER01!: The downloaded file size of $clientFile does not match the server side file size. Deleting the ZIP download, and will reattempt."
        Remove-Tree -Path 'C:\Windows\LTSvc\Packages\OS\Win10x64.1803'
        $checkFile = Test-Path 'C:\Windows\LTSvc\Packages\OS\Win10x64.1803\Prox64.1803.zip' -PathType Leaf
        If(!$checkFile){
            Write-Output "!DLF: Successfully deleted all downloaded files, restarting the download."
        }
        Else{
            Write-Output "Failed to remove $clientFile"
        }
    }
}
Else{
    Write-Output "!DLF:"
}
