function htonl(a) { 
	return rshift(and(a, 0xff000000), 24) + rshift(and(a, 0xff0000), 8) + lshift(and(a, 0xff00), 8) + lshift(and(a, 0xff), 24); 
}
BEGIN {
	fp_data_base = strtonum(fp_data_base);
	fp_config_base = strtonum(fp_config_base); 
	fp_data_end_ptr = strtonum(fp_data_end_ptr);
	fp_config_base_ptr_1 = strtonum(fp_config_base_ptr_1);
	fp_config_end_ptr_1 = strtonum(fp_config_end_ptr_1);
	fp_config_base_ptr_2 = strtonum(fp_config_base_ptr_2);
	fp_config_end_ptr_2 = strtonum(fp_config_end_ptr_2);
	ramstart = strtonum(ramstart);

	fp_config_origbase = strtonum(fp_config_origbase);
	fp_config_origend = strtonum(fp_config_origend);
	fp_data_origend = strtonum(fp_data_origend);

	fp_data_end = fp_data_base;
	fp_config_end = fp_config_base;

	printf "%s: %s FORCE\n", out_file, src_file;

	# Firmwares that ship their own populated flashpatch table (e.g. the BCM43596a0
	# 9.86.13 build has 155 ROM bugfix entries) must keep those entries: relocate the
	# stock table to the new config area and append nexmon's entries after it.
	# Starting from an empty table silently disables every stock ROM patch.
	if (fp_data_origend > fp_data_base && fp_config_origend > fp_config_origbase) {
		n = fp_config_origend - fp_config_origbase;
		printf "\t$(Q)dd if=$@ of=gen/fp_orig_config.bin bs=1 status=none skip=$$((0x%08x - 0x%08x)) count=%d\n", fp_config_origbase, ramstart, n;
		printf "\t$(Q)dd if=gen/fp_orig_config.bin of=$@ bs=1 status=none conv=notrunc seek=$$((0x%08x - 0x%08x))\n", fp_config_base, ramstart;
		printf "\t$(Q)printf \"  COPIED %d stock flashpatch entries\\n\"\n", n / 8;
		fp_data_end = fp_data_origend;
		fp_config_end = fp_config_base + n;
	}
}
{
	if ($2 == "FLASHPATCH") {
		printf "\t$(Q)$(CC)objcopy -O binary -j .text." $4 " $< gen/section.bin && dd if=gen/section.bin of=$@ bs=1 conv=notrunc seek=$$((0x%08x - 0x%08x))\n", fp_data_end, ramstart;
		printf "\t$(Q)printf %08x%08x | xxd -r -p | dd of=$@ bs=1 conv=notrunc seek=$$((0x%08x - 0x%08x))\n", htonl(strtonum($1)), htonl(fp_data_end), fp_config_end, ramstart;
		printf "\t$(Q)printf \"  FLASHPATCH %s @ %s\\n\"\n", $4, $1;
		fp_data_end = fp_data_end + 8;
		fp_config_end = fp_config_end + 8;
	}
}
END {
	printf "\t$(Q)printf %08x | xxd -r -p | dd of=$@ bs=1 conv=notrunc seek=$$((0x%08x - 0x%08x))\n", htonl(fp_data_end), fp_data_end_ptr, ramstart;
	printf "\t$(Q)printf \"  PATCH fp_data_end @ 0x%08x\\n\"\n", fp_data_end_ptr;
	printf "\t$(Q)printf %08x | xxd -r -p | dd of=$@ bs=1 conv=notrunc seek=$$((0x%08x - 0x%08x))\n", htonl(fp_config_base), fp_config_base_ptr_1, ramstart;
	printf "\t$(Q)printf \"  PATCH fp_config_base @ 0x%08x\\n\"\n", fp_config_base_ptr_1;
	printf "\t$(Q)printf %08x | xxd -r -p | dd of=$@ bs=1 conv=notrunc seek=$$((0x%08x - 0x%08x))\n", htonl(fp_config_end), fp_config_end_ptr_1, ramstart;
	printf "\t$(Q)printf \"  PATCH fp_config_end @ 0x%08x\\n\"\n", fp_config_end_ptr_1;
	printf "\t$(Q)printf %08x | xxd -r -p | dd of=$@ bs=1 conv=notrunc seek=$$((0x%08x - 0x%08x))\n", htonl(fp_config_base), fp_config_base_ptr_2, ramstart;
	printf "\t$(Q)printf \"  PATCH fp_config_base @ 0x%08x\\n\"\n", fp_config_base_ptr_2;
	printf "\t$(Q)printf %08x | xxd -r -p | dd of=$@ bs=1 conv=notrunc seek=$$((0x%08x - 0x%08x))\n", htonl(fp_config_end), fp_config_end_ptr_2, ramstart;
	printf "\t$(Q)printf \"  PATCH fp_config_end @ 0x%08x\\n\"\n", fp_config_end_ptr_2;
	printf "\n\nFORCE:\n"
}
