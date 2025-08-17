# MCSBtool Description
The MCSB (Mount, Copy, Set Boot) tool is used to create bootable media efficiently.

# What are the main steps that are executed?
This tool uses three main steps to ensure your bootable media is prepared for installation and usage on real hardware.
1. Mount, the first step, which mounts the provided ISO image based on the path.
2. Copy, the second step, copies the files of the mounted image to your provided USB or other device path.
3. Set Boot, the final step, sets your external media boot configuration and others to ensure you can boot into the flash drive or SSD.

# What is the coding language of this tool?
This tool was primarily designed for PowerShell due to its efficiency.

# Credits
Credit to me (Poireguy), yippee!

# Extras
Adding custom drivers has been implemented; you're welcome!
More parameters, but these parameters are optional.

# Example parameter usage
```PowerShell
C:\Users\JohnDoe\MCSBtool> .\mcsb.ps1 -BIOS "MBR" -ISOImage "C:\Users\JohnDoe\images\Windows11.iso" -DrvPath "C:\Users\JohnDoe\MyDrivers\" -USBPath "F:\"
```
