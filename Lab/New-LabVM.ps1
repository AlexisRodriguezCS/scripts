#Requires -Version 5.1
<#
    Creates the Hyper-V VM for the lab domain controller. Run on the host (Windows 10/11 Pro or Server
    with Hyper-V enabled). You need a Windows Server ISO: the free 180-day evaluation is enough.
    https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025

    .\Lab\New-LabVM.ps1 -IsoPath "C:\Users\me\Downloads\server2025.iso"

    Put the lab on another drive with -Path:
    .\Lab\New-LabVM.ps1 -IsoPath "...\server2025.iso" -Path "S:\Hyper-V"

    Then install Windows in the VM window, and run Lab\Initialize-LabDomain.ps1 inside it.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$IsoPath,

    [string]$Name = "LAB-DC01",

    # 4 GB is plenty for a domain controller with a handful of test users
    [int]$MemoryGB = 4,

    [int]$DiskGB = 60,

    # "Default Switch" gives the VM internet through the host, with no network setup
    [string]$SwitchName = "Default Switch",

    # Where the VM and its disk go, e.g. a second SSD: -Path "S:\Hyper-V".
    # Left out, Hyper-V's own default folders are used.
    [string]$Path
)

$ErrorActionPreference = "Stop"

if (Get-VM -Name $Name -ErrorAction SilentlyContinue) {
    throw "A VM called $Name already exists. Delete it first, or pass a different -Name."
}

if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    throw "No virtual switch called '$SwitchName'. Run Get-VMSwitch to see what you have."
}

# Keep the VM's config and its disk together, so the whole lab is one folder to copy or delete
$vmRoot  = if ($Path) { $Path } else { (Get-VMHost).VirtualMachinePath }
$diskDir = if ($Path) { Join-Path $Path "Disks" } else { (Get-VMHost).VirtualHardDiskPath }
$null    = New-Item -ItemType Directory -Path $vmRoot, $diskDir -Force

$vhdPath = Join-Path $diskDir "$Name.vhdx"
if (Test-Path $vhdPath) { throw "$vhdPath already exists; delete it or pick another -Name" }

Write-Host "Creating $Name ($MemoryGB GB RAM, $DiskGB GB disk) in $vmRoot..." -ForegroundColor Cyan

# Generation 2 = UEFI, which Server 2019 and later expect
$vm = New-VM -Name $Name -Generation 2 -MemoryStartupBytes ($MemoryGB * 1GB) `
             -Path $vmRoot -NewVHDPath $vhdPath -NewVHDSizeBytes ($DiskGB * 1GB) -SwitchName $SwitchName

# Dynamic memory: the DC idles at about 1.5 GB, so the host keeps the rest
Set-VMMemory  -VMName $Name -DynamicMemoryEnabled $true -MinimumBytes 1GB -MaximumBytes ($MemoryGB * 1GB)
Set-VMProcessor -VMName $Name -Count 2

# Windows Setup needs Secure Boot to trust the Microsoft certificate
Set-VMFirmware -VMName $Name -EnableSecureBoot On -SecureBootTemplate "MicrosoftWindows"

# Boot from the ISO the first time
$dvd = Add-VMDvdDrive -VMName $Name -Path $IsoPath -Passthru
Set-VMFirmware -VMName $Name -FirstBootDevice $dvd

# Checkpoints on a domain controller cause more problems than they solve (USN rollback)
Set-VM -Name $Name -CheckpointType Disabled -AutomaticStartAction Nothing

Write-Host @"

$Name is ready. Next:

  1. Start it and open the console:
       Start-VM -Name $Name ; vmconnect.exe localhost $Name

  2. Press a key at "Press any key to boot from CD" (it only waits a few seconds;
     if you miss it, reset the VM and try again).

  3. Install Windows Server: pick the **Desktop Experience** edition, Custom install,
     the whole disk. Set an Administrator password you'll remember.

  4. Inside the VM, copy this repo in (or just Lab\Initialize-LabDomain.ps1) and run:
       .\Initialize-LabDomain.ps1 -DomainName lab.local

     It promotes the machine to a domain controller, reboots, and when you run it
     again it builds the OUs, groups and a ready-made Config\Clients\Lab config.
"@ -ForegroundColor Green
