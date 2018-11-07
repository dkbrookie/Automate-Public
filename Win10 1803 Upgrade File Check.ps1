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
        Remove-Tree -Path 'C:\Windows\LTSvc\Packages\OS\Win10x64.1803'
        $checkFile = Test-Path 'C:\Windows\LTSvc\Packages\OS\Win10x64.1803\Prox64.1803.zip' -PathType Leaf
        If(!$checkFile){
            Write-Output "!DLF"
        }
        Else{
            Write-Output "!FAIL"
        }
    }
    Else{
        Write-Output "!SUC"
    }
}
Else{
    Write-Output "!DLF"
}
