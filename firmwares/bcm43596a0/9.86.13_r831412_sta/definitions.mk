NEXMON_CHIP=CHIP_VER_BCM43596a0
NEXMON_CHIP_NUM=`$(NEXMON_ROOT)/buildtools/scripts/getdefine.sh $(NEXMON_CHIP)`
NEXMON_FW_VERSION=FW_VER_9_86_13_r831412_sta
NEXMON_FW_VERSION_NUM=`$(NEXMON_ROOT)/buildtools/scripts/getdefine.sh $(NEXMON_FW_VERSION)`

NEXMON_ARCH=armv7-r

RAM_FILE=bcmdhd_sta.bin_c0
RAMSTART=0x160000
RAMSIZE=0xe0000

ROM_FILE=rom.bin
ROMSTART=0x0
ROMSIZE=0xe0000

# read directly from the stock firmware at the hndrte_reclaim_0_end patch slot (0x169d48)
HNDRTE_RECLAIM_0_END=0x1e40f0

PATCHSIZE=0x4000
PATCHSTART=$$(($(HNDRTE_RECLAIM_0_END) - $(PATCHSIZE)))

# original ucode start and size -- found via a byte-identical header match against the
# known BCM43596a0 reference builds (this build's ucode is a different microcode
# revision, 1060.20541 vs 1060.2064, so only a leading prefix matched verbatim; size
# derived from the firmware's own templateram boundary, see notes.md)
UCODESTART=0x1d3b7c
UCODESIZE=0xedc8

# original template ram start and size -- content found byte-identical to the known
# reference builds' templateram blob, located directly in this firmware
TEMPLATERAMSTART=0x1e2948
TEMPLATERAMSIZE=0x17a8

# Verified on hardware (see notes): these slots are correct. The stock flashpatch table
# (FP_CONFIG_ORIGBASE..ORIGEND, 155 entries) must be preserved when relocating it.
FP_DATA_END_PTR=0x1acf58
# fp_check_success
FP_CONFIG_BASE_PTR_1=0x1aaee0
FP_CONFIG_END_PTR_1=0x1aaee4
# fp_apply_patches
FP_CONFIG_BASE_PTR_2=0x1ab044
FP_CONFIG_END_PTR_2=0x1ab040
FP_CONFIG_SIZE=0x800
FP_CONFIG_BASE=$$(($(PATCHSTART) - $(FP_CONFIG_SIZE)))

# Stock flashpatch tables of this build: config 0x161800..0x161cd8, data 0x161000..0x1614d8
# (read from the stock firmware; FP_DATA_END_PTR's stock value is FP_DATA_ORIGEND).
FP_DATA_BASE=0x161000
FP_DATA_ORIGEND=0x1614d8
FP_CONFIG_ORIGBASE=0x161800
FP_CONFIG_ORIGEND=0x161cd8
