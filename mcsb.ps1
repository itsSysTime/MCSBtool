
param (
    [string]$ISOPath,
    [string]$DrvPath,
    [string]$USBPath,
    [string]$BIOS,
    [string]$EFIPath
)

function Invoke-Drivers {
    param (
        [string]$DrvPath,
        [string]$Drive
    )

    if (Test-Path $DrvPath) {
        $validDrivers = Get-ChildItem -Path $DrvPath -Recurse -Include *.inf, *.sys, *.cat
        if ($validDrivers.Count -gt 0) {
            $SentTo = Join-Path $Drive "$WinPEDriver$"
            $FallBack = Join-Path $Drive "EXEDrv"
            md $SentTo
            $validDrivers | Copy-Item -Destination "$SentTo" -Force
            Write-Host "Drivers copied successfully.`nThose copied to the directory will be mounted as Setup, or Windows PE, boots." -ForegroundColor Green
            if (Get-ChildItem -Path $DrvPath -Filter "*.exe" -File -ErrorAction SilentlyContinue) {
                md $FallBack
                Write-Host ".EXE files or installers were detected.`nIn order to install these drivers, you must either extract the driver files OR install these after the device your bootable media uses is set up." -ForegroundColor Yellow
            }

            Log "Drivers successfully copied: $($validDrivers.Count)"
        } else {
            Write-Host "No valid driver files found." -ForegroundColor Yellow
            Log "No valid drivers found. Drivers will not be installed."
        }
    } else {
        Write-Host "Driver path invalid." -ForegroundColor Yellow
        Log "Driver path invalid."
    }
}


# Ensure script is run as admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating script to Administrator..." -ForegroundColor Cyan
    $params = $MyInvocation.UnboundArguments + $MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object {
        if ($_.Value) { "-$($_.Key) `"$($_.Value)`"" }
    }
    $joined = $params -join ' '
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" $joined" -Verb RunAs
    exit
}


$logPath = "$PSScriptRoot\mcsb_log.txt"
function Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $msg" | Out-File -FilePath $logPath -Append
}

Log "=== MCSB Session Started ==="

if ($MyInvocation.BoundParameters.ContainsKey('USBPath')) {
    $Drive = $USBPath
    $Drive = $Drive.TrimEnd('\')
} else {
    $Drive = Read-Host @"
Welcome to the Automated MCS/MCSB Tool for creating bootable media.
To get started, please enter the drive letter to your USB or other insertable device (e.g., R:\)
"@
}

Write-Host "`nVerifying drive, please wait..." -ForegroundColor Cyan
Log "Drive input: $Drive"

if (-not $Drive) {
    Write-Host "Drive path is null or empty." -ForegroundColor Red
    Log "Drive path was null."
    exit 1
}

if (Test-Path $Drive) {
    cls

    if ($MyInvocation.BoundParameters.ContainsKey('ISOPath')) {
        $Image = $ISOPath
    } else {
        $Image = Read-Host "Please enter the full path to your optical disk image"
    }

    Log "ISO input: $Image"

    if (Test-Path $Image) {
        try {
            $DriveInfo = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $Drive }
            If ($DriveInfo.DriveType -ne 5) {
                Log "Attempting to mount ISO..."
                $Mount = Mount-DiskImage -ImagePath "$Image" -PassThru
                $DriveLtr = ($Mount | Get-Volume).DriveLetter

                if (-not $DriveLtr) {
                    throw "ISO could not mount."
                }

                Write-Host "`nMounted ISO. Drive letter is: ${DriveLtr}:" -ForegroundColor Yellow
                Log "Mounted ISO at ${DriveLtr}:"
                Start-Sleep -Seconds 5
            } else {
                Write-Host "CD/DVD detected, proceed with optical disc steps." -ForegroundColor Cyan
                Start-Sleep -Seconds 2
            }
            

            cls
            If ($DriveInfo.DriveType -ne 5) {
                Write-Host "Copying files, please wait..." -ForegroundColor Cyan
                $xcopyArgs = "${DriveLtr}:\* ${Drive}\* /H /E /F /J"
                Log "xcopy args: $xcopyArgs"
                Start-Process xcopy.exe -ArgumentList $xcopyArgs -NoNewWindow -RedirectStandardOutput temp.txt -Wait
                Get-Content temp.txt | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
                Remove-Item temp.txt -Force
                Start-Sleep -Seconds 5
                cls
            } elseif ($DriveInfo.DriveType -eq 5) {
                Write-Host "Burning to CD/DVD, please wait..." -ForegroundColor Yellow
                $ibargs = "/d ${Drive} ${Image}"
                Start-Process isoburn.exe -ArgumentList $ibargs -NoNewWindow -RedirectStandardOutput temp.txt -Wait
                Get-Content temp.txt | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
                Remove-Item temp.txt -Force
                Start-Sleep -Seconds 5
                cls
            }

                $DrvIn = Read-Host "Would you like to install drivers? (Y/N)"
                if ($DrvIn.ToUpper() -eq "Y") {
                    if (-not $MyInvocation.BoundParameters.ContainsKey('DrvPath')) {
                        $DrvPath = Read-Host "Please provide a directory containing drivers (full path)"
                    }
                    Log "Driver path: $DrvPath"
                    Invoke-Drivers -DrvPath $DrvPath -Drive $Drive
                } else {
                    Write-Host "Drivers will be skipped, proceeding forward.." -ForegroundColor Yellow
                    Log "Drivers are not provided or skipped."
                }

            $OS = Read-Host "Is your version of Windows below Vista? (Y/N)"
            $code = if ($OS.ToUpper() -eq "Y") { "nt52" } else { "nt60" }
            If ($OS -eq "Y") {
                Write-Host "While this generally applies to versions Vista and below, it is also advised to enable CSM or use CSMWrap for Windows 7 and below on UEFI systems." -ForegroundColor Yellow
            }
            
            Log "Boot code: $code"

            Start-Sleep -Seconds 5
            cls

            if (-not $MyInvocation.BoundParameters.ContainsKey('BIOS')) {
                $BIOS = Read-Host "Finished copying files.`nWhat does your system run on? (UEFI/BIOS)"
            }

            Log "BIOS scheme: $BIOS"

            if ($BIOS.ToUpper() -eq "UEFI") {

                bootsect.exe /$code ${Drive} /force
                $EFID = Join-Path -Path "$PSScriptRoot" -ChildPath "EFI"
                $ActualDriver = Join-Path -Path "$EFID" -ChildPath "uefi-ntfs.iso"
                Write-Host "Fetching online UEFI:NTFS and other driver patches, please wait..." -ForegroundColor Cyan
                try {
                    Invoke-WebRequest -Uri "https://github.com/poireguy/MCSBtool/raw/refs/heads/main/uefi-ntfs.iso" -OutFile $ActualDriver -DisableKeepAlive
                } catch {
                    $ActualDriver = Read-Host "Fetching files failed.`nPlease provide the path to your offline copy of the drivers image"
                    If (Test-Path $ActualDriver) {
                        Write-Host "The script will proceed forward." -ForegroundColor Green
                    } else {
                        Write-Host "The following path could not be resolved: ${ActualDriver}" -ForegroundColor Red
                        return
                    }
                }

                $Ltrs = [char[]]([int][char]'C'..[int][char]'Z') 
                $Used = (Get-PSDrive -PSProvider FileSystem).Name
                $UnusedLtrs = $Ltrs | Where-Object { $_ -notin $Used }
                $RandLtr = Get-Random -InputObject $UnusedLtrs
                $DrvEx = ($Drive -replace ':', '') -replace '\\', ''
                $DrivePart = Get-Partition -DriveLetter $DrvEx
                $Disk = Get-Disk -Number $DrivePart.DiskNumber

                Write-Host "Your EFI partition will use the letter: $RandLtr"
                $dpScr = @"
sel dis $Disk
create par primary size=272
format fs=fat32 quick
set id=EF OVERRIDE
exit
"@
                $dpOut = Join-Path -Path "$PSScriptRoot" -ChildPath "dpOutput.log"
                $dpScr | diskpart.exe | Out-File $dpOut -Encoding ASCII
                Start-Process diskpart.exe -ArgumentList "/s", $dpOut -Wait
                $MountDrivers = Mount-DiskImage "$ActualDriver" -PassThru
                $MoDrLtr = ($MountDrivers | Get-Volume).DriveLetter
                $rcArgs = "`"${MoDrLtr}:`" `"${RandLtr}:`" /E /MIR /CopyAll /J /R:1 /W:1"
                Log "Downloading EFI files from local web copy..."

                Log "Mounted EFI drivers at: $MoDrLtr"
                $robolog = Join-Path -Path "$PSScriptRoot" -ChildPath "mcsb.robocopy.log" 
                Start-Process robocopy.exe -ArgumentList $rcArgs -RedirectStandardOutput $robolog -Wait
                $RoboCon = Get-Content -Path "$robolog"
                Log "Copied EFI files: $RoboCon"
                Write-Host "$RoboCon" -ForegroundColor Yellow

            } elseif ($BIOS.ToUpper() -eq "BIOS") {
                bootsect.exe /$code ${Drive} /mbr /force
                $volnum = (Get-Volume -DriveLetter $Drive | Get-Partition).PartitionNumber
                $diskpartScript = @"
select volume $volnum
active
exit
"@
                $diskpartScript | Out-File dp.txt -Encoding ASCII
                Start-Process diskpart.exe -ArgumentList @("/s", "dp.txt") -Wait
                Remove-Item dp.txt -Force
                Log "MBR boot sector applied and volume activated."
            } else {
                Write-Host "Invalid scheme or system." -ForegroundColor Red
                Log "Invalid BIOS scheme entered."
                pause
            }

            Write-Host "`nYour bootable media is ready." -ForegroundColor Green
            Log "Bootable media creation complete."
            pause
        } catch {
            Write-Host "An error occurred. Cleaning up..." -ForegroundColor Red
            Log "Exception: $($_.Exception.Message)"
            Dismount-DiskImage -ImagePath "$Image" -ErrorAction SilentlyContinue
            Remove-Item "${Drive}\*.iso" -Recurse -Force -ErrorAction SilentlyContinue
            exit -1073741510
        }
    } else {
        cls
        Write-Host "Your optical disk image was not found." -ForegroundColor Red
        Log "ISO not found at $Image"
        pause
    }
} else {
    Write-Host "Your drive was not found." -ForegroundColor Red
    Log "Drive not found at ${Drive}\"
    pause
}

