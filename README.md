# MCSBtool Description
The MCSB (Mount, Copy, Set Boot) tool is used to create bootable media efficiently.

# What are the main steps that are executed?
This tool uses three main steps to ensure your bootable media is prepared for installation and usage on real hardware.
1. Mount, the first step, which mounts the provided ISO image based on the path.
2. Copy, the second step, copies the files of the mounted image to your provided USB or other device path.
3. Set Boot, the final step, sets your external media boot configuration and others to ensure you can boot into the flash drive or SSD.

## Format your USB drive accordingly
Due to Windows Image (.WIM) and .ESD sizes in ISOs, some USBs will be formatted accordingly. With smaller _D:\sources\install.wim_ (replace D:\ with your USB letter) or **install.esd** sizes, you should format the partition as FAT32 for compatibility between UEFI and Legacy BIOS (MBR). For larger images up to **4 Gigabytes** and above, format the drive as _NTFS_ to ensure your USB drive can boot properly with modern systems and space for your .WIM or .ESD image. I encourage formatting USB drives as so, according to OS; image sizes can vary with editions and versions.

| OS                      | Format As |
|-------------------------|-----------|
| Windows 7 SP1 and older | FAT32     |
| Windows Server 2012 and newer    | NTFS      |

# What is the coding language of this tool?
This tool was primarily designed for PowerShell due to its efficiency.

# Credits
Credit to me (Poireguy), yippee!

# Extras
Adding custom drivers has been implemented; you're welcome!
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

# UEFI/NTFS/exFAT Support
Extended UEFI support is a major change that has been added in the commit _[7f13f7](https://github.com/poireguy/MCSBtool/commit/7f13f703a8c1625ab0a861c866b59e62f46ba2ed)_.
A re-formatted optical disc image (copied over from Rufus's FAT12 .img file) has been added to the root of the repository; you can install this with the script in case of offline media creation.

# Work In Progress and new potential features
I am planning to add these things to commit(s) for the _MCSB Tool_ PowerShell script:
- Add a file size check for install.wim on the mounted ISO drive BEFORE the copying files step, but only if the USB is formatted as FAT32. If over 4 GiB (or simplify to 3.7 GiB) was verified as the file size from the UDF-mounted drive, prompt to split the file into 2-3 versions (mounted drives are only read, so prompt the user for a directory to store these files temporarily and then proceed to write these after the copying process by deleting install.wim, if *.swm is present in %TMP% and copy these .swm files to **USB**:\sources\. This might be an extensive process with DISM.exe
