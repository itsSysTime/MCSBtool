# MCSBtool Description
The MCSB (Mount, Copy, Set Boot) tool is used to create bootable media efficiently.

# What are the main steps that are executed?
This tool uses three main steps to ensure your bootable media is prepared for installation and usage on real hardware.
1. Mount, the first step, which mounts the provided ISO image based on the path.
2. Copy, the second step, copies the files of the mounted image to your provided USB or other device path.
3. Set Boot, the final step, sets your external media boot configuration and others to ensure you can boot into the flash drive or SSD.

## Format your USB drive accordingly
Due to Windows Image (.WIM) and .ESD sizes in ISOs, some USBs will be formatted accordingly. With smaller _D:\sources\install.wim_ (replace D:\ with your USB letter) or **install.esd** sizes, you should format the partition as FAT32 for compatibility between UEFI and Legacy BIOS (MBR). For larger images up to **4 Gigabytes** and above, format the drive as _NTFS_ to ensure your USB drive can boot properly with modern systems and space for your .WIM or .ESD image. I encourage formatting USB drives as so, according to the OS; image sizes can vary with editions and versions.

| OS                      | Format As |
|-------------------------|-----------|
| Windows 7 SP1 and older | FAT32     |
| Windows Server 2012 and newer    | NTFS      |

# What is the coding language of this tool?
This tool was primarily designed for PowerShell due to its efficiency.


# Extras
Adding custom drivers has been implemented; you're welcome! `$WinPEDriver$` path has been added to load drivers on WinPE/Setup boot automatically. Windows Vista and below do not support this method and require manual driver loading into the base image or installing drivers after the setup process. Sorry!
<br>More parameters, but these parameters are optional.

Let your .inf, .sys, and .cat files join the installation. Sure, you can also implement the
drivers into the install.wim/install.esd and boot.wim images, however, this takes time and can take up
excessive storage.

## What about CDs and DVDs?
The support for CDs and DVDs with isoburn.exe has been added in the recent commit _6e7bdaf_. So, enjoy!

# Example parameter usage
```PowerShell
C:\Users\JohnDoe\MCSBtool> .\mcsb.ps1 -BIOS "UEFI" -ISOImage "C:\Users\JohnDoe\images\Windows11.iso" -DrvPath "C:\Users\JohnDoe\MyDrivers\" -USBPath "F:\"
```
# Manual steps you can execute to perform a similar effect
In order is where you perform these steps. However, this process assumes you have acknowledged:
- Size of Install.WIM file inside of a mounted ISO file before copying files, FAT32 is recommended if the file is below ~3.7 GiB
- Size of your drive (CD/DVD/USB, USBs are recommended for modern installations, while DVDs are recommended for legacy versions. Vista works on USB installs, but below may require a DVD. CDs cannot hold a modern or pre-modern installation. Floppy support is unknown.)
- Version of OS to install. The process assumes you acknowledge what you need to install the OS. Check online for more information!
- ISO or optical disc image file. The process simply assumes you have this to proceed.

Because of the script's intended view on Microsoft Windows, manual steps may need to be performed for other OSes.

Now, you can proceed with the steps in the specified order:
1. Mount your image file
2. Copy the files inside the newly mounted virtual drive to your USB/CD/DVD drive.
3. Make sure your information is correct. The disk scheme and firmware are also detailed for more legacy OSes. GPT and legacy BIOS are not natively compatible, including MBR and UEFI firmware.
4. Finally, set and apply boot information such as boot entries, boot code (for Windows), and other vital information based on your operating system and system type.

Regarding drivers, if you cannot run an installer for the driver(s) you need for Windows, you can also use _PnP Utility_ (`pnputil.exe`) or _Windows Driver Kit_ (also known as **WDK**). You should find a version that supports the intended operating system version in the table below (_Driver Development Kit / Device Development Kit_ included):

| OS                      | WDK Version(s) | Note(s)
|-------------------------|----------------|---------
| Windows Vista, XP SP3/later, 7 SP1, Server 2008 & R2, Server 2003 SP1/later & x64 Editions | WDK 7.1.0 | Outdated and no longer available from Microsoft. Required to build for these versions.
| Windows 2000 | Windows 2000 DDK | Outdated and no longer available from Microsoft.
| Windows 7, 8, 8.1, Server 2012, Server 2016, 10, 11, Server 2022, Server 2019 | WDK 10.0 | The latest WDK 10.0 releases are bundled with the Windows SDK, which are also compatible with Visual Studio 2022. You must have WDK 10.0.19041.0 or an earlier version to build drivers for Windows 7, 8, or 8.1, unless you have manually configured it for later versions of WDK 10.0. Visual Studio 2019 or older may be required for WDK 10.0.19041.0 or earlier versions.
| Windows 11, Server 2025 | WDK 11.0 | Requires Visual Studio 2022 and can build for versions of Windows 10 and later, including Windows Server 2016, 2019, and 2025. It does not support building drivers for versions earlier than Windows 10. Microsoft recommends using the latest WDK version for the corresponding version(s) of Windows.

Using `pnputil.exe`, you can run (e.g.):
```Batch
pnputil.exe -i -a C:\Users\JaneDoe\drivers\*.inf
```
The command above adds driver packages to the store and installs them for an existing device with the Hardware ID provided in the .inf files (in versions below Windows 10, refined commands introduced in various versions).

For Windows 10 and above, you can use:
```Batch
pnputil.exe /add-driver C:\Users\JaneDoe\drivers\*.inf /install
```

When using **DevCon**, you must first find the Hardware ID of the device listed in the .inf file that comes with your .cat and/or .sys file(s) by viewing it in other software such as Notepad. Once you find it, copy it, and you can use the command below (example) to install a driver:
```Batch
devcon.exe install C:\Users\NotDoe\drvpack\ATIx64\wddmAMDRHD.inf [Device hardware ID here]
```

You can replace `install` with `update` in the command to update an existing driver. You should use the hardware ID found in the device's details tab in Device Manager to update it with DevCon.

# Extended file system support on UEFI systems
Extended UEFI support is a major change that has been added in the commit _[7f13f7](https://github.com/poireguy/MCSBtool/commit/7f13f703a8c1625ab0a861c866b59e62f46ba2ed)_.
A re-formatted optical disc image (copied over from Rufus's FAT12 .img file since many modern and even pre-modern systems cannot mount 70s-80s era file systems, et cetera.) has been added to the root of the repository; you can install this with the script in case of offline media creation. The script also assumes you have at least 272 MiB free of unallocated space on the same disk as the USB/CD/DVD's partition, where the boot files only use 1-3 MiB of space. You may use your minimum allowed partition size for this, so prepare this partition manually.

# Work In Progress and new potential features
This script is a work in progress.
## Failed ideas
- Smart file system formatting. Add a file size check for install.wim on the mounted ISO drive BEFORE the copying files step, but only if the USB is formatted as FAT32. If over 4 GiB (or simplify to 3.7 GiB) was verified as the file size from the UDF-mounted drive, prompt to split the file into 2-3 versions (mounted drives are only read, so prompt the user for a directory to store these files temporarily and then proceed to write these after the copying process by deleting install.wim, if *.swm is present in %TMP% and copy these .swm files to **USB**:\sources\. This might be an extensive process with DISM.exe. However, this idea has not worked in beta testing and was actually scrapped.

# Q&A
1. Will you add a GUI version?
2. No, I will not add a GUI version, as simplicity is intended.

3. Will there be Linux or Mac versions?
4. This script is intended for support on Microsoft Windows. You can use a container or a virtual machine to use this tool and proceed forward. This is because the use of PowerShell and system functions is built in and used by Windows.

5. What about Windows Vista and below?
6. For legacy versions where PowerShell is not installed by default, it is recommended to install it to use this script.
