# BCM43596a0 9.86.13_r831412_sta (Inseego/Novatel MiFi 8800L) -- port notes

Status: monitor mode (`wl monitor 1|2`) verified on hardware alongside a running AP.
3000/3000 captured frames had a valid FCS, radiotap header correct, channel annotation correct.

## The AP-bringup trap (pc=0x5669a lr=0x69683) -- root cause
Not an address problem. The 5 flashpatch bootstrap slots in definitions.mk were correct all along.
The stock firmware ships a populated flashpatch table (155 ROM bugfix entries):
config 0x161800..0x161cd8, data 0x161000..0x1614d8. The build's
`flashpatches.bcm43596.mk.awk` repointed the table at a fresh *empty* area, silently
disabling every stock ROM patch, and AP bring-up then hit an unpatched ROM bug.
Fix: copy the stock table to the new location and append nexmon entries after it
(FP_CONFIG_ORIGBASE/ORIGEND and FP_DATA_ORIGEND in definitions.mk).
Bisect evidence: empty table => trap, with or without monitor flashpatch; stock table preserved => clean.

## Verified on hardware
- wlc+0x250 is the monitor field (only byte that flips 1->2 on `wl monitor 1` -> `wl monitor 2`).
- wl_sendup_newdrv = 0x1622a4 (byte-identical body to 9.96.4's 0x1624ac, unique match).
- channel2freq via wlc_phy_chan2freq_acphy_newdvr, returning ci[1], gives correct MHz.

## Gotchas
- Statics in the "patch" region are NOT zeroed by the loader: guard with a magic value.
- Firmware console is dark (dhd_msg_level is load-time only). Deliberate trap (`.short 0xde00`
  with data in r0-r6) is a usable data channel: dmesg prints the registers.
- ucode.bin / templateram.bin (inputs to the generated src/*.c) are slices of the stock dump at
  UCODESTART/UCODESIZE and TEMPLATERAMSTART/TEMPLATERAMSIZE.
- Device: firmware loads from /lib/firmware/bcm/bcm4359_network.bin on the rw rootfs; reboot to reload.
  adb works independent of WiFi, so a bad firmware is recoverable.
