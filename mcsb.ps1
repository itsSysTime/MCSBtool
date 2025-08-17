param (
    [string]$ISOPath,
    [string]$DrvPath,
    [string]$USBPath,
    [string]$BIOS,
    [string]$EFIPath
)

if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('USBPath')) {
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

    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ISOPath')) {
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
                if (-not $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('DrvPath')) {
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

            # Continue with rest of your script...
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
