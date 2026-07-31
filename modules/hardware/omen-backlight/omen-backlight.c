// SPDX-License-Identifier: MIT
/*
 * omen-backlight - mirror a sysfs backlight device to the OMEN Max EC PWM byte.
 *
 * On the HP OMEN Max 16-ah0xxx in Hybrid graphics mode the firmware updates
 * CBL1 but never runs the WMAA path that propagates it to ECPW, so the panel
 * ignores every standard backlight interface. Writing ECPW directly restores
 * control.
 *
 * Register and approach from hp-omen-max-linux-brightness-fix (MIT):
 * https://github.com/kcamporacosta/hp-omen-max-linux-brightness-fix
 */

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

/* \_SB.PC00.LPCB.ECPW, via OperationRegion EWRM at 0xFD400C00 offset 0xF5 */
#define EC_REG 0xFD400CF5UL

/* Firmware computes ECPW = CBL1 * 2 and CBL1 saturates at 100 */
#define EC_MAX 200

/* The register is model specific; refuse to touch it on anything else */
#define DMI_PRODUCT "/sys/class/dmi/id/product_name"
#define DMI_EXPECT "16-ah0xxx"

/* Safety net if actual_brightness never raises a sysfs notification */
#define POLL_TIMEOUT_MS 250

/* nvidia_0 only appears once the nvidia module has probed */
#define DEVICE_WAIT_S 60

static volatile uint8_t *ec_byte;

static int read_uint(const char *path, unsigned long *out) {
  FILE *f = fopen(path, "r");
  if (!f)
    return -1;
  int n = fscanf(f, "%lu", out);
  fclose(f);
  return n == 1 ? 0 : -1;
}

static int guard_dmi(void) {
  char buf[256];
  FILE *f = fopen(DMI_PRODUCT, "r");
  if (!f) {
    fprintf(stderr, "cannot read %s: %s\n", DMI_PRODUCT, strerror(errno));
    return -1;
  }
  if (!fgets(buf, sizeof buf, f)) {
    fclose(f);
    fprintf(stderr, "cannot read %s\n", DMI_PRODUCT);
    return -1;
  }
  fclose(f);

  if (!strstr(buf, DMI_EXPECT)) {
    buf[strcspn(buf, "\n")] = '\0';
    fprintf(stderr,
            "refusing to run: expected a '%s' product name, found '%s'\n",
            DMI_EXPECT, buf);
    return -1;
  }
  return 0;
}

static int map_ec(void) {
  long page_size = sysconf(_SC_PAGESIZE);
  if (page_size <= 0) {
    fprintf(stderr, "cannot determine page size\n");
    return -1;
  }

  unsigned long base = EC_REG & ~((unsigned long)page_size - 1UL);
  unsigned long off = EC_REG - base;

  int fd = open("/dev/mem", O_RDWR | O_SYNC);
  if (fd < 0) {
    fprintf(stderr, "open(/dev/mem): %s\n", strerror(errno));
    return -1;
  }

  void *map = mmap(NULL, (size_t)page_size, PROT_READ | PROT_WRITE, MAP_SHARED,
                   fd, (off_t)base);
  close(fd);
  if (map == MAP_FAILED) {
    fprintf(stderr, "mmap(0x%lx): %s\n", base, strerror(errno));
    return -1;
  }

  ec_byte = (volatile uint8_t *)map + off;
  return 0;
}

static void ec_write(unsigned long value) {
  if (value > EC_MAX)
    value = EC_MAX;
  *ec_byte = (uint8_t)value;
  __sync_synchronize();
}

/*
 * Scale the sysfs device's current level onto the EC range and apply it.
 *
 * Only writes on an actual change
 */
static int mirror(const char *dir, unsigned long min_ec) {
  static long last = -1;
  char path[PATH_MAX];
  unsigned long cur, max;

  snprintf(path, sizeof path, "%s/brightness", dir);
  if (read_uint(path, &cur))
    return -1;

  snprintf(path, sizeof path, "%s/max_brightness", dir);
  if (read_uint(path, &max) || max == 0)
    return -1;

  if (cur > max)
    cur = max;

  unsigned long ec = (cur * EC_MAX + max / 2) / max;
  if (ec < min_ec)
    ec = min_ec;

  if ((long)ec == last)
    return 0;

  ec_write(ec);
  last = (long)ec;
  return 0;
}

static int wait_for_device(const char *dir) {
  char path[PATH_MAX];
  unsigned long v;

  snprintf(path, sizeof path, "%s/brightness", dir);
  for (int i = 0; i <= DEVICE_WAIT_S; i++) {
    if (read_uint(path, &v) == 0)
      return 0;
    sleep(1);
  }
  fprintf(stderr, "timed out waiting for %s\n", path);
  return -1;
}

/*
 * The backlight class raises a sysfs notification on actual_brightness, so
 * poll() wakes us on real changes instead of spinning. The timeout only covers
 * devices that never notify.
 */
static int watch(const char *dir, unsigned long min_ec) {
  char path[PATH_MAX];
  char buf[64];

  if (wait_for_device(dir))
    return -1;

  snprintf(path, sizeof path, "%s/actual_brightness", dir);
  int fd = open(path, O_RDONLY);
  if (fd >= 0 && read(fd, buf, sizeof buf) < 0) {
    close(fd);
    fd = -1;
  }
  if (fd < 0)
    fprintf(stderr, "%s unavailable, falling back to timed polling\n", path);

  if (mirror(dir, min_ec)) {
    fprintf(stderr, "cannot read brightness from %s\n", dir);
    return -1;
  }

  for (;;) {
    if (fd >= 0) {
      struct pollfd pfd = {.fd = fd, .events = POLLPRI | POLLERR};
      if (poll(&pfd, 1, POLL_TIMEOUT_MS) < 0 && errno != EINTR) {
        fprintf(stderr, "poll: %s\n", strerror(errno));
        return -1;
      }
      /* Consuming the value re-arms the next notification */
      lseek(fd, 0, SEEK_SET);
      if (read(fd, buf, sizeof buf) < 0) { /* keep going on transient errors */
      }
    } else {
      usleep(POLL_TIMEOUT_MS * 1000);
    }

    mirror(dir, min_ec);
  }
}

static void usage(const char *argv0) {
  fprintf(stderr,
          "Usage:\n"
          "  %s get\n"
          "  %s set <0-%d>\n"
          "  %s watch <sysfs-backlight-dir> [min-ec]\n",
          argv0, argv0, EC_MAX, argv0);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    usage(argv[0]);
    return 2;
  }

  if (guard_dmi())
    return 1;
  if (map_ec())
    return 1;

  if (!strcmp(argv[1], "get") && argc == 2) {
    printf("%u\n", (unsigned)*ec_byte);
    return 0;
  }

  if (!strcmp(argv[1], "set") && argc == 3) {
    char *end = NULL;
    errno = 0;
    unsigned long v = strtoul(argv[2], &end, 10);
    if (errno || !end || *end != '\0' || v > EC_MAX) {
      fprintf(stderr, "value must be 0-%d\n", EC_MAX);
      return 2;
    }
    ec_write(v);
    printf("%u\n", (unsigned)*ec_byte);
    return 0;
  }

  if (!strcmp(argv[1], "watch") && (argc == 3 || argc == 4)) {
    unsigned long min_ec = 0;
    if (argc == 4) {
      char *end = NULL;
      errno = 0;
      min_ec = strtoul(argv[3], &end, 10);
      if (errno || !end || *end != '\0' || min_ec > EC_MAX) {
        fprintf(stderr, "min-ec must be 0-%d\n", EC_MAX);
        return 2;
      }
    }
    return watch(argv[2], min_ec) ? 1 : 0;
  }

  usage(argv[0]);
  return 2;
}
