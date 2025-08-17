param (
    [string]$ISOPath,
    [string]$DrvPath,
    [string]$USBPath,
    [string]$BIOS,
    [string]$EFIPath
)

if ($MyInvocation.BoundParameters.ContainsKey('USBPath')) {
    $Drive = $USBPath
} else {
    $Drive = Read-Host @"
Welcome to the Automated MCS/MCSB Tool for creating bootable media.
To get started, please enter the drive letter to your USB or other insertable device (e.g., R:\)
"@
}

Write-Host "`nVerifying drive, please wait..." -ForegroundColor Cyan

if (-not $Drive) {
    Write-Host "Drive path is null or empty." -ForegroundColor Red
    exit 1
}

if (Test-Path $Drive) {
    cls

    if ($MyInvocation.BoundParameters.ContainsKey('ISOPath')) {
        $Image = $ISOPath
    } else {
        $Image = Read-Host "Please enter the full path to your optical disk image"
    }

    if (Test-Path $Image) {
        try {
            $Mount = Mount-DiskImage -ImagePath "$Image" -PassThru
            $DriveLtr = ($Mount | Get-Volume).DriveLetter
            Write-Host "`nMounted ISO. Drive letter is: ${DriveLtr}:" -ForegroundColor Yellow
            Start-Sleep -Seconds 5

            $drvin = Read-Host "Would you like to install drivers? (Y/N)"
            if ($drvin.ToUpper() -eq "Y") {
                if (-not $MyInvocation.BoundParameters.ContainsKey('DrvPath')) {
                    $DrvPath = Read-Host "Please provide a directory containing drivers (full path)"
                }

                if (Test-Path $DrvPath) {
                    $validDrivers = Get-ChildItem -Path $DrvPath -Recurse -Include *.inf, *.sys, *.cat
                    if ($validDrivers.Count -gt 0) {
                        md "${Drive}:\Drivers"
                        $validDrivers | Copy-Item -Destination "${Drive}:\Drivers" -Force
                        Write-Host "Drivers copied successfully. During Setup, direct the installer to: ${Drive}:\Drivers\ to install these drivers." -ForegroundColor Green
                    } else {
                        Write-Host "No valid driver files found in $DrvPath." -ForegroundColor Yellow
                    }
                } elseif ($DrvPath -eq $null) {
                    Write-Host "Drivers will not be added to your installation." -ForegroundColor Yellow
                }
            }

            cls
            Write-Host "Copying files, do not terminate the batch job..." -ForegroundColor Cyan
            $xcopyArgs = "${DriveLtr}:\* ${Drive}\* /H /E /F /J"
            Start-Process xcopy.exe -ArgumentList $xcopyArgs -NoNewWindow -RedirectStandardOutput temp.txt -Wait
            Get-Content temp.txt | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
            Remove-Item temp.txt -Force
            Start-Sleep -Seconds 5
            cls

            $OS = Read-Host "Is your version of Windows below Vista? (Y/N)"
            if ($OS.ToUpper() -eq "Y") {
                $rule = "nt52"
            } else {
                $rule = "nt60"
            }

            Start-Sleep -Seconds 5
            cls

            if (-not $MyInvocation.BoundParameters.ContainsKey('BIOS')) {
                $BIOS = Read-Host "Finished copying files.`nWhat is your BIOS or disk scheme to apply the boot sector on? (GPT/MBR)"
            }

            if ($BIOS.ToUpper() -eq "GPT") {
                bootsect.exe /$rule ${DriveLtr} /force
                $EFIVol = Get-Volume | Where-Object { $_.FileSystemLabel -eq "SYSTEM" }
                if ($EFIVol) {
                    $EFILtr = $EFIVol.DriveLetter
                    Write-Host "EFI volume detected as ${EFILtr}:" -ForegroundColor Yellow
                    $EFIPath = "${EFILtr}:\EFI"
                    if (Test-Path $EFIPath) {
                        $efiCopyArgs = "${Drive}:\efi\* ${EFIPath}\* /E /F /K /H /J"
                        Start-Process xcopy.exe -ArgumentList $efiCopyArgs -NoNewWindow -RedirectStandardOutput temp.txt -Wait
                        Get-Content temp.txt | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
                        Remove-Item temp.txt -Force
                    } else {
                        $EFIPath = Read-Host "EFI system path not found. Please provide the EFI files path (e.g., W:\EFI)"
                        if (Test-Path $EFIPath) {
                            $efiCopyArgs = "${Drive}:\efi\* ${EFIPath}\* /E /F /K /H /J"
                            Start-Process xcopy.exe -ArgumentList $efiCopyArgs -NoNewWindow -Wait
                        } else {
                            Write-Host "Provided EFI path is invalid." -ForegroundColor Red
                        }
                    }
                } else {
                    Write-Host "EFI volume not found." -ForegroundColor Red
                }
            } elseif ($BIOS.ToUpper() -eq "MBR") {
                bootsect.exe /$rule ${DriveLtr} /mbr /force
                $volnum = (Get-Volume -DriveLetter $DriveLtr | Get-Partition).PartitionNumber
                $diskpartScript = @"
select volume $volnum
active
exit
"@
                $diskpartScript | Out-File dp.txt -Encoding ASCII
                Start-Process diskpart.exe -ArgumentList @("/s", "dp.txt") -Wait
                Remove-Item dp.txt -Force
            } else {
                Write-Host "Invalid scheme or system." -ForegroundColor Red
                pause
            }

            Write-Host "`nYour bootable media is ready." -ForegroundColor Green
            Write-Host "You may use it for other purposes after this, as no other commands will execute." -ForegroundColor Green
            Write-Host "Created by NK, coded in PowerShell." -ForegroundColor Cyan
            pause
        } catch {
            Write-Host "An error occurred. Cleaning up..." -ForegroundColor Red
            Dismount-DiskImage -ImagePath "$Image"
            Remove-Item "${Drive}\*" -Recurse -Force -ErrorAction SilentlyContinue
            exit -1073741510
        }
    } else {
        cls
        Write-Host "Your optical disk image was not found." -ForegroundColor Red
        pause
    }
} else {
    Write-Host "Your drive was not found." -ForegroundColor Red
    pause
}
