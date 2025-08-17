param (
    [string]$ISOPath
    [string]$Drivers
    [string]$USBPath
)

If ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('USBPath')) {
    $Drive = $USBPath
} else {
    $Drive = Read-Host @"
    Welcome to the Automated MCS/MCSB Tool for creating bootable media.
    To get started, please enter the drive letter to your USB or other insertable device (e.g., R:\)
"@
}

Write-Host "`nVerifying drive, please wait..." -ForegroundColor Cyan

if (Test-Path $Drive) {
    cls

    If ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ISOPath')) {
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
            
            If ($drvin.ToUpper() -eq "Y") {
                If ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('DrvPath')) {
                    $DrvPath = $Drivers
                } else {
                    $DrvPath = Read-Host "Please provide a directory containing drivers (full path)"
                }

                If (Test-Path $DrvPath) {
                    md ${Drive}:\Drivers
                    Get-ChildItem -Path $DrvPath -Recurse -Include *.inf, *.sys, *.cat | Copy-Item -Destination "${Drive}:\Drivers" -Force
                    Write-Host "During Setup, direct the installer to: ${Drive}:\Drivers\ to install Drivers." -ForegroundColor Green
                } elseif ($drvpath -eq $null) {
                    Write-Host "Drivers will not be added to your installation." -ForegroundColor Yellow
                }
            cls

            Write-Host "Copying files, do not terminate the batch job..." -ForegroundColor Cyan
            $xcopyArgs = "${DriveLtr}:\* ${Drive}\* /H /E /F /J"
            Start-Process xcopy.exe -ArgumentList $xcopyArgs -NoNewWindow -RedirectStandardOutput temp.txt -Wait
            Get-Content temp.txt | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
            Remove-Item temp.txt -Force
            Start-Sleep -Seconds 5
            cls

            $os = Read-Host "Is your version of Windows below Vista? (Y/N)"
            if ($os.ToUpper() -eq "Y") {
                $rule = "nt52"
            } else {
                $rule = "nt60"
            }

            Start-Sleep -Seconds 5
            cls
            $bios = Read-Host "Finished copying files.`nWhat is your BIOS or disk scheme to apply the boot sector on? (GPT/MBR)"

            if ($bios.ToUpper() -eq "GPT") {
                bootsect.exe /$rule ${DriveLtr} /force
                $efiVol = Get-Volume | Where-Object { $_.FileSystemLabel -eq "SYSTEM" }
                if ($efiVol) {
                    $efiLetter = $efiVol.DriveLetter
                    Write-Host "EFI volume detected as ${efiLetter}:" -ForegroundColor Yellow
                    $efiPath = "${efiLetter}:\EFI"
                    if (Test-Path $efiPath) {
                        $efiCopyArgs = "${Drive}:\efi\* ${efiPath}\* /E /F /K /H /J"
                        Start-Process xcopy.exe -ArgumentList $efiCopyArgs -NoNewWindow -RedirectStandardOutput temp.txt -Wait
                        Get-Content temp.txt | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
                        Remove-Item temp.txt -Force
                    } else {
                        $efiPath = Read-Host "EFI system path not found. Please provide the EFI files path (e.g., W:\EFI)"
                        if (Test-Path $efiPath) {
                            $efiCopyArgs = "${Drive}:\efi\* ${efiPath}\* /E /F /K /H /J"
                            Start-Process xcopy.exe -ArgumentList $efiCopyArgs -NoNewWindow -Wait
                        } else {
                            Write-Host "Provided EFI path is invalid." -ForegroundColor Red
                        }
                    }
                } else {
                    Write-Host "EFI volume not found." -ForegroundColor Red
                }
            } elseif ($bios -eq "MBR") {
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
        Write-Host "Your optical disk Image was not found." -ForegroundColor Red
        pause
    }
} else {
    Write-Host "Your Drive was not found." -ForegroundColor Red
    pause
}
