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
- The ucode-compressed region's exact bytes depend on the zlib compression *level* used at build
  time (setup_env.sh's `$(ZLIBFLATE)`); harmless if it ever differs between builds -- the device only
  cares about the inflated bytes, which are deterministic. Don't chase byte-for-byte rebuild diffs
  here without first checking whether the *decompressed* content actually changed.

## Frame injection -- status
`NEX_INJECT_FRAME`/`inject_frame()`/`vendor_radiotap.c` are ported into this port's `src/` (copied
verbatim from the fully-supported 9.96.4_sta_c0 reference, same silicon) and compile/link cleanly,
but are **unreachable**: `wlc_ioctl_hook` itself has no `at()` entry for this exact firmware build,
i.e. nothing ever calls it. That hook is a RAM-resident function-pointer *word* written by ROM init
code, not an executable byte sequence, so it isn't findable by the signature-match technique that
located everything else in this port (e.g. `wl_sendup_newdrv`). 9.96.4's address for it (0x1C3CE4)
is confirmed build-specific, not a chip-wide constant (the other BCM43596a0 reference, 9.75.155.45,
doesn't wire this hook at all, and the stock dword at that address differs across all three builds).
No ROM dump or `rom_extraction` support exists for this chip anywhere in nexmon, so there's no sound
way to locate the real address for 9.86.13 without one. **Do not guess-and-flash this address** --
an address picked without evidence is written blind into firmware RAM with no way to predict the
outcome; this is a different, much worse risk profile than reverting a known slot to a known value.

**However, injection itself is now proven working on this exact physical chip/device**, via a
temporary cross-flash of the unmodified 9.96.4_sta_c0 firmware (built straight from its own
`patches/bcm43596a0/9.96.4_sta_c0/nexmon`, no changes needed -- it already has the hook wired at
0x1C3CE4 and `NEX_INJECT_FRAME` implemented). This is firmware cross-flashed onto different retail
hardware than it shipped on (Galaxy S7 -> this MiFi), so treat every step below as something that
needs re-verifying if the real device's NVRAM/calibration or host driver ever changes:
- Boots fine on this device (`GET_REVINFO` succeeds, same op_mode/MAC as the real firmware).
- `wlc_ioctl_hook` is genuinely live: `NEX_GET_VERSION_STRING` (413) returns a real nexmon version
  string over the SIOCDEVPRIVATE ioctl path (see `utilities/nexprobe/`).
- Dual-band (RSDB) does NOT work on this device under 9.96.4: `wlan1` (2.4GHz) loops forever trying
  to create its AP interface and failing (`wl_cfg80211_change_virtual_iface: Cannot change the
  interface for GO or SOFTAP`, confirmed against public bcmdhd source -- that function only has a
  clean path for the *primary* interface; a second concurrent AP depends on the firmware correctly
  reporting RSDB capability, which this non-RSDB-wired hardware doesn't). The retry loop saturates
  the radio enough that `wlan0`'s own beacon becomes intermittent/invisible. **Fix**: disable the
  2.4GHz radio through the authoritative control plane, NOT `config.xml` (that flag alone doesn't
  stop the retry loop -- something else re-asserts it):
  ```sh
  printf '0\n0\n' | sysintcli setWiFiPrimaryProfileEnabled   # band 0=2.4GHz, enabled=0
  sysintcli applyWiFiProfiles
  # ... to re-enable afterward:
  printf '0\n1\n' | sysintcli setWiFiPrimaryProfileEnabled
  sysintcli applyWiFiProfiles
  ```
  With `wlan1` off, `wlan0` is fully stable (confirmed: 0 hangs/traps/retries over a 30s+ watch).
- Renaming the test AP (to avoid the real device's saved-credential confusion on a phone that's
  already connected to it) must go through a full hostapd restart, not `hostapd_cli wps_config`
  live-reconfigure -- the latter updates hostapd's internal state and `get_config` reflects it, but
  the actual over-the-air beacon push can fail silently (`Frequency set failed: -1 Operation not
  permitted`, `Failed to set beacon parameters`) while reporting success, leaving the OLD ssid still
  broadcasting. Edit `/tmp/wifi/hostapd/wlanN_hostapd.conf` directly and `kill` the hostapd PID
  (exactly once -- don't race it with a manual relaunch, a supervisor respawns it with the new
  config within ~1-10s); verify with `wl -i wlanN ssid` (the chip-level truth) not just
  `hostapd_cli get_config` (hostapd's possibly-stale internal belief).
- An injected raw frame cannot carry valid WPA2/CCMP encryption without the live session key, so the
  target BSS must be open (no `wpa=`/`wpa_passphrase=` lines) for an encrypted client to accept it.
- Confirmed end-to-end: crafted a raw 802.11 data frame (unencrypted, FromDS) carrying an ARP
  request "who has <client_ip>, tell <ap_ip>" from the AP's own MAC, sent via `NEX_INJECT_FRAME`
  (`utilities/nexprobe/nexinject_arp_example.c`). Captured a genuine ARP *reply* back from the real
  associated client (opcode 2, sender = the client's real MAC/IP) in a plain `tcpdump -i wlan0`,
  proving the frame was genuinely transmitted, received, and answered -- not a loopback artifact.
