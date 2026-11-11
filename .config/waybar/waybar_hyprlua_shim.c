#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dlfcn.h>
#include <ctype.h>
#include <dirent.h>
#include <sys/socket.h>

struct udev_device;
struct udev_enumerate;

static ssize_t (*real_write)(int fd, const void *buf, size_t count) = NULL;
static ssize_t (*real_send)(int sockfd, const void *buf, size_t len, int flags) = NULL;
static ssize_t (*real_sendto)(int sockfd, const void *buf, size_t len, int flags,
                              const struct sockaddr *dest_addr, socklen_t addrlen) = NULL;
static int (*real_udev_enumerate_add_match_subsystem)(struct udev_enumerate *udev_enumerate,
                                                      const char *subsystem) = NULL;
static const char *(*real_udev_device_get_sysattr_value)(struct udev_device *udev_device,
                                                         const char *sysattr) = NULL;
static const char *(*real_udev_device_get_subsystem)(struct udev_device *udev_device) = NULL;

static void init_real(void) {
    if (!real_write) real_write = dlsym(RTLD_NEXT, "write");
    if (!real_send) real_send = dlsym(RTLD_NEXT, "send");
    if (!real_sendto) real_sendto = dlsym(RTLD_NEXT, "sendto");
    if (!real_udev_enumerate_add_match_subsystem)
        real_udev_enumerate_add_match_subsystem = dlsym(RTLD_NEXT, "udev_enumerate_add_match_subsystem");
    if (!real_udev_device_get_sysattr_value)
        real_udev_device_get_sysattr_value = dlsym(RTLD_NEXT, "udev_device_get_sysattr_value");
    if (!real_udev_device_get_subsystem)
        real_udev_device_get_subsystem = dlsym(RTLD_NEXT, "udev_device_get_subsystem");
}

static int has_real_backlight(void) {
    DIR *dir = opendir("/sys/class/backlight");
    if (!dir) return 0;
    struct dirent *entry;
    int found = 0;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] != '.') {
            found = 1;
            break;
        }
    }
    closedir(dir);
    return found;
}

int udev_enumerate_add_match_subsystem(struct udev_enumerate *udev_enumerate, const char *subsystem) {
    init_real();
    if (subsystem && strcmp(subsystem, "leds") == 0 && has_real_backlight()) {
        /* When real /sys/class/backlight devices exist (e.g., on laptop),
           do not pollute Waybar's backlight module with /sys/class/leds. */
        return 0;
    }
    return real_udev_enumerate_add_match_subsystem(udev_enumerate, subsystem);
}

const char *udev_device_get_sysattr_value(struct udev_device *udev_device, const char *sysattr) {
    init_real();
    if (udev_device && sysattr && strcmp(sysattr, "bl_power") == 0 && real_udev_device_get_subsystem) {
        const char *subsys = real_udev_device_get_subsystem(udev_device);
        if (subsys && strcmp(subsys, "leds") == 0) {
            /* Mark non-backlight LED devices (e.g., NIC or keyboard LEDs on desktop PC)
               as unpowered for Waybar's Backlight module so it calls event_box_.hide(). */
            return "1";
        }
    }
    return real_udev_device_get_sysattr_value(udev_device, sysattr);
}

static int is_pure_integer(const char *s) {
    if (!s || !*s) return 0;
    for (const char *p = s; *p; p++) {
        if (!isdigit((unsigned char)*p)) return 0;
    }
    return 1;
}

static void escape_lua(const char *src, char *dst, size_t dst_size) {
    size_t j = 0;
    for (size_t i = 0; src[i] && j + 2 < dst_size; i++) {
        if (src[i] == '"' || src[i] == '\\') {
            dst[j++] = '\\';
        }
        dst[j++] = src[i];
    }
    dst[j] = '\0';
}

static int rewrite_dispatch(const void *in_buf, size_t in_len, char *out_buf, size_t out_max, size_t *out_len) {
    if (!in_buf || in_len < 9 || in_len > 1024) return 0;

    if (memcmp(in_buf, "dispatch ", 9) != 0) return 0;

    int has_newline = (((const char *)in_buf)[in_len - 1] == '\n');

    char temp[1024];
    size_t copy_len = in_len;
    if (copy_len >= sizeof(temp)) copy_len = sizeof(temp) - 1;
    memcpy(temp, in_buf, copy_len);
    temp[copy_len] = '\0';

    while (copy_len > 0 && (temp[copy_len - 1] == '\r' || temp[copy_len - 1] == '\n' || temp[copy_len - 1] == ' ')) {
        temp[--copy_len] = '\0';
    }

    const char *p = temp + 9;
    while (*p == ' ') p++;

    char target[1024];
    target[0] = '\0';

    if (strncmp(p, "workspace name:", 15) == 0) {
        const char *arg = p + 15;
        while (*arg == ' ') arg++;
        char escaped[512];
        escape_lua(arg, escaped, sizeof(escaped));
        snprintf(target, sizeof(target), "dispatch hl.dsp.focus({workspace=\"%s\"})", escaped);
    } else if (strncmp(p, "workspace ", 10) == 0) {
        const char *arg = p + 10;
        while (*arg == ' ') arg++;
        if (is_pure_integer(arg)) {
            snprintf(target, sizeof(target), "dispatch hl.dsp.focus({workspace=%s})", arg);
        } else {
            char escaped[512];
            escape_lua(arg, escaped, sizeof(escaped));
            snprintf(target, sizeof(target), "dispatch hl.dsp.focus({workspace=\"%s\"})", escaped);
        }
    } else if (strncmp(p, "focusworkspaceoncurrentmonitor name:", 36) == 0) {
        const char *arg = p + 36;
        while (*arg == ' ') arg++;
        char escaped[512];
        escape_lua(arg, escaped, sizeof(escaped));
        snprintf(target, sizeof(target), "dispatch hl.dsp.focus({workspace=\"%s\"})", escaped);
    } else if (strncmp(p, "focusworkspaceoncurrentmonitor ", 31) == 0) {
        const char *arg = p + 31;
        while (*arg == ' ') arg++;
        if (is_pure_integer(arg)) {
            snprintf(target, sizeof(target), "dispatch hl.dsp.focus({workspace=%s})", arg);
        } else {
            char escaped[512];
            escape_lua(arg, escaped, sizeof(escaped));
            snprintf(target, sizeof(target), "dispatch hl.dsp.focus({workspace=\"%s\"})", escaped);
        }
    } else if (strncmp(p, "togglespecialworkspace", 22) == 0) {
        const char *arg = p + 22;
        while (*arg == ' ') arg++;
        if (*arg != '\0') {
            char escaped[512];
            escape_lua(arg, escaped, sizeof(escaped));
            snprintf(target, sizeof(target), "dispatch hl.dsp.workspace.toggle_special(\"%s\")", escaped);
        } else {
            snprintf(target, sizeof(target), "dispatch hl.dsp.workspace.toggle_special()");
        }
    } else if (strncmp(p, "exit", 4) == 0) {
        snprintf(target, sizeof(target), "dispatch hl.dsp.exit()");
    } else if (strncmp(p, "dpms on", 7) == 0) {
        snprintf(target, sizeof(target), "dispatch hl.dsp.dpms({action=\"on\"})");
    } else if (strncmp(p, "dpms off", 8) == 0) {
        snprintf(target, sizeof(target), "dispatch hl.dsp.dpms({action=\"off\"})");
    } else {
        return 0;
    }

    if (has_newline) {
        size_t tlen = strlen(target);
        if (tlen + 2 < sizeof(target)) {
            target[tlen] = '\n';
            target[tlen + 1] = '\0';
        }
    }

    size_t final_len = strlen(target);
    if (final_len >= out_max) return 0;
    memcpy(out_buf, target, final_len);
    *out_len = final_len;
    return 1;
}

ssize_t write(int fd, const void *buf, size_t count) {
    init_real();
    char out_buf[1024];
    size_t out_len = 0;
    if (rewrite_dispatch(buf, count, out_buf, sizeof(out_buf), &out_len)) {
        ssize_t ret = real_write(fd, out_buf, out_len);
        if (ret >= 0) return (ssize_t)count;
        return ret;
    }
    return real_write(fd, buf, count);
}

ssize_t send(int sockfd, const void *buf, size_t len, int flags) {
    init_real();
    char out_buf[1024];
    size_t out_len = 0;
    if (rewrite_dispatch(buf, len, out_buf, sizeof(out_buf), &out_len)) {
        ssize_t ret = real_send(sockfd, out_buf, out_len, flags);
        if (ret >= 0) return (ssize_t)len;
        return ret;
    }
    return real_send(sockfd, buf, len, flags);
}

ssize_t sendto(int sockfd, const void *buf, size_t len, int flags,
               const struct sockaddr *dest_addr, socklen_t addrlen) {
    init_real();
    char out_buf[1024];
    size_t out_len = 0;
    if (rewrite_dispatch(buf, len, out_buf, sizeof(out_buf), &out_len)) {
        ssize_t ret = real_sendto(sockfd, out_buf, out_len, flags, dest_addr, addrlen);
        if (ret >= 0) return (ssize_t)len;
        return ret;
    }
    return real_sendto(sockfd, buf, len, flags, dest_addr, addrlen);
}
