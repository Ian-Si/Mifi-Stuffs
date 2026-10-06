#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>

#define SIOCDEVPRIVATE 0x89F0
#define NEX_INJECT_FRAME 408

struct nex_ioctl {
    unsigned int cmd;
    void *buf;
    unsigned int len;
    int set;
    unsigned int used;
    unsigned int needed;
    unsigned int driver;
};

/* AP: MAC 18:ee:86:a9:60:20, IP 192.168.1.1
 * Client (phone): MAC e6:38:cc:dd:97:cd, IP 192.168.1.8
 * Benign ARP request: "who has 192.168.1.8, tell 192.168.1.1" -- a device
 * answers this iff it owns that IP, which is standard ARP behavior and not
 * disruptive to anything else on the network. */

static const unsigned char ap_mac[6]     = {0x18,0xee,0x86,0xa9,0x60,0x20};
static const unsigned char client_mac[6] = {0xe6,0x38,0xcc,0xdd,0x97,0xcd};
static const unsigned char ap_ip[4]      = {192,168,1,1};
static const unsigned char client_ip[4]  = {192,168,1,8};

int main(int argc, char **argv) {
    const char *iface = argc > 1 ? argv[1] : "wlan0";

    unsigned char frame[60];
    memset(frame, 0, sizeof(frame));

    /* 802.11 header (24 bytes): Data, FromDS=1, unencrypted */
    frame[0] = 0x08; /* version=0, type=Data(2), subtype=0 */
    frame[1] = 0x02; /* ToDS=0, FromDS=1 */
    frame[2] = 0x00; frame[3] = 0x00; /* duration */
    memcpy(frame + 4,  client_mac, 6); /* addr1 = DA */
    memcpy(frame + 10, ap_mac, 6);     /* addr2 = BSSID/TA */
    memcpy(frame + 16, ap_mac, 6);     /* addr3 = SA (AP is the original source) */
    frame[22] = 0x10; frame[23] = 0x00; /* seq=1, frag=0 */

    /* LLC/SNAP header for ARP (8 bytes) */
    unsigned char llc[8] = {0xAA,0xAA,0x03,0x00,0x00,0x00,0x08,0x06};
    memcpy(frame + 24, llc, 8);

    /* ARP request (28 bytes) */
    unsigned char *arp = frame + 32;
    arp[0]=0x00; arp[1]=0x01;          /* hw type = ethernet */
    arp[2]=0x08; arp[3]=0x00;          /* proto type = IPv4 */
    arp[4]=6;    arp[5]=4;             /* hw len, proto len */
    arp[6]=0x00; arp[7]=0x01;          /* opcode = request */
    memcpy(arp + 8,  ap_mac, 6);       /* sender mac */
    memcpy(arp + 14, ap_ip, 4);        /* sender ip */
    memset(arp + 18, 0, 6);            /* target mac = unknown */
    memcpy(arp + 24, client_ip, 4);    /* target ip (what we're asking about) */

    /* struct inject_frame { u16 len; u8 pad; u8 type; u8 data[]; } */
    unsigned char buf[4 + sizeof(frame)];
    memset(buf, 0, sizeof(buf));
    unsigned short flen = sizeof(frame) + 4; /* +4 accounts for the FCS the radio appends */
    buf[0] = flen & 0xff;
    buf[1] = (flen >> 8) & 0xff;
    buf[2] = 0;    /* pad */
    buf[3] = 0;    /* type=0: no radiotap header present, firmware adds a dummy one */
    memcpy(buf + 4, frame, sizeof(frame));

    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, iface, IFNAMSIZ - 1);

    struct nex_ioctl ioc;
    memset(&ioc, 0, sizeof(ioc));
    ioc.cmd = NEX_INJECT_FRAME;
    ioc.buf = buf;
    ioc.len = sizeof(buf);
    ioc.set = 1;
    ioc.driver = 0;
    ifr.ifr_data = (void *) &ioc;

    int s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0) { perror("socket"); return 1; }

    errno = 0;
    int ret = ioctl(s, SIOCDEVPRIVATE, &ifr);
    printf("inject ret=%d errno=%d (%s)\n", ret, errno, strerror(errno));
    close(s);
    return 0;
}
