# nexprobe / nexinject

Minimal, dependency-free alternatives to `utilities/nexutil` for quickly testing a
firmware's custom `wlc_ioctl_hook` (the `NEX_*` ioctls in `patches/include/nexioctls.h`)
from the target device's own userspace, without needing libnl/netlink or the rest of
nexutil's build.

Both talk to the driver the same way `nexutil`/`wl` do: `ioctl(s, SIOCDEVPRIVATE, &ifr)`
on an `AF_INET`/`SOCK_DGRAM` socket, with `ifr.ifr_data` pointing at a
`struct nex_ioctl { cmd, buf, len, set, used, needed, driver }`. This is the bcmdhd
private-ioctl path (`__nex_driver_io` in `utilities/libnexio/libnexio.c`), not the
nl80211/netlink path used when `USE_NETLINK` is defined for nexutil.

## nexprobe.c
Generic GET probe: `nexprobe <cmd> [iface]` sends the given ioctl `cmd` with
`set=0` and a 1536-byte buffer, and dumps whatever comes back. Useful first step to
confirm a `wlc_ioctl_hook` is actually wired for a given firmware build before
building anything more specific — e.g. `nexprobe 413 wlan0` should return
`nexmon_ver: ...` (`NEX_GET_VERSION_STRING`) if the hook fires.

## nexinject_arp_example.c
Worked example of a SET-mode call: constructs a complete raw 802.11 data frame
(FromDS, unencrypted) carrying an ARP request, wraps it in the
`struct inject_frame { u16 len; u8 pad; u8 type; u8 data[]; }` format
`NEX_INJECT_FRAME` (408) expects (see `src/ioctl.c` / `src/injection.c` in any port
that has it wired), and sends it with `set=1`. The MACs/IPs in this file are
hardcoded for a specific test session — treat it as a template, not a tool: copy it
and substitute your own AP/client MAC+IP before using it.

Confirmed working end-to-end on a BCM43596a0 (Inseego/Novatel MiFi 8800L) running the
9.96.4_sta_c0 firmware: the injected ARP request produced a genuine ARP reply from a
real associated client, captured on the AP as ordinary bridged traffic. Note the
target network must be open (unencrypted) for this to work — a raw injected frame has
no way to carry a valid WPA2/CCMP MIC without the live session key, so an encrypted
BSS will silently drop it regardless of whether injection itself works.

## Building
Needs an ARM Linux (not bare-metal) cross-compiler matching the *device's own* CPU
(e.g. `arm-linux-gnueabihf-gcc`), which is a different toolchain from the one used to
build the firmware patch itself (that one targets the WiFi chip's own ARM core, not
the host CPU). On a Debian/Ubuntu host without root, this can be obtained by
downloading .deb packages directly (`apt-get download gcc-arm-linux-gnueabihf
cpp-arm-linux-gnueabihf binutils-arm-linux-gnueabihf libc6-armhf-cross
libc6-dev-armhf-cross linux-libc-dev-armhf-cross gcc-11-arm-linux-gnueabihf
cpp-11-arm-linux-gnueabihf libgcc-11-dev-armhf-cross libgcc-s1-armhf-cross`) and
extracting each with `dpkg -x <deb> <root>` into a local prefix, then:

```
arm-linux-gnueabihf-gcc --sysroot=<root> -static -O2 nexprobe.c -o nexprobe
```

(`LD_LIBRARY_PATH=<root>/usr/lib/x86_64-linux-gnu` is needed for the cross `as`/`ld`
to find their own `libbfd`/`libopcodes` when invoked this way.) `-static` avoids
needing to match the device's libc at runtime. Push with `adb push` and `chmod 755`.
