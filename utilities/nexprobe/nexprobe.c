#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <stdbool.h>

#define SIOCDEVPRIVATE 0x89F0

struct nex_ioctl {
    unsigned int cmd;
    void *buf;
    unsigned int len;
    int set;
    unsigned int used;
    unsigned int needed;
    unsigned int driver;
};

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <cmd> [iface]\n", argv[0]);
        return 1;
    }
    unsigned int cmd = strtoul(argv[1], 0, 0);
    const char *iface = argc > 2 ? argv[2] : "wlan0";

    char buf[1536];
    memset(buf, 0, sizeof(buf));

    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, iface, IFNAMSIZ - 1);

    struct nex_ioctl ioc;
    memset(&ioc, 0, sizeof(ioc));
    ioc.cmd = cmd;
    ioc.buf = buf;
    ioc.len = sizeof(buf);
    ioc.set = 0;
    ioc.driver = 0;

    ifr.ifr_data = (void *) &ioc;

    int s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0) { perror("socket"); return 1; }

    errno = 0;
    int ret = ioctl(s, SIOCDEVPRIVATE, &ifr);
    printf("cmd=%u iface=%s ret=%d errno=%d (%s)\n", cmd, iface, ret, errno, strerror(errno));
    if (ret == 0) {
        printf("buf (first 64 bytes hex): ");
        for (int i = 0; i < 64; i++) printf("%02x ", (unsigned char) buf[i]);
        printf("\nbuf (as string): %s\n", buf);
    }
    close(s);
    return 0;
}
