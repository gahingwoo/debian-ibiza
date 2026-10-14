/* LD_PRELOAD shim that stands in for Android's property service inside the Debian "android" chroot.
 * Freestanding (no libc): it is loaded by bionic's linker and overrides bionic's __system_property_* API with a tiny
 * in-process table. Without it libbinder waits for "servicemanager.ready" forever in a busy loop (WaitForPropertyCreation).
 * Build: gcc -O2 -shared -fPIC -nostdlib -ffreestanding -fno-builtin -fno-stack-protector -o libibizaprop.so propshim.c */

typedef unsigned int u32;
typedef unsigned long usize;

#define MAXP 192
struct prop_info { u32 serial; char value[92]; char name[96]; };   /* only our own use; callers treat it as opaque */
static struct prop_info props[MAXP];
static int nprops;
static u32 area_serial = 2;

static usize slen(const char *s) { usize n = 0; while (s[n]) n++; return n; }
static int seq(const char *a, const char *b) { while (*a && *a == *b) { a++; b++; } return *a == *b; }
static void scopy(char *d, const char *s, usize max) { usize i = 0; while (s[i] && i + 1 < max) { d[i] = s[i]; i++; } d[i] = 0; }

static void nap(long sec, long nsec) {
    long ts[2] = { sec, nsec };
    register long x0 __asm__("x0") = (long)ts;
    register long x1 __asm__("x1") = 0;
    register long x8 __asm__("x8") = 101;               /* nanosleep */
    __asm__ volatile("svc 0" : "+r"(x0) : "r"(x1), "r"(x8) : "memory");
}

static struct prop_info *lookup(const char *name) {
    for (int i = 0; i < nprops; i++) if (seq(props[i].name, name)) return &props[i];
    return 0;
}
static struct prop_info *put(const char *name, const char *value) {
    struct prop_info *p = lookup(name);
    if (!p) { if (nprops >= MAXP) return 0; p = &props[nprops++]; scopy(p->name, name, sizeof p->name); p->serial = 2; }
    scopy(p->value, value, sizeof p->value);
    p->serial += 2; area_serial += 2;
    return p;
}

static long sys3(long n, long a, long b, long c) {
    register long x0 __asm__("x0") = a; register long x1 __asm__("x1") = b; register long x2 __asm__("x2") = c; register long x8 __asm__("x8") = n;
    __asm__ volatile("svc 0" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x8) : "memory");
    return x0;
}
/* Android init turns androidboot.X=Y on the kernel command line into ro.boot.X=Y. */
static void import_cmdline(void) {
    static char buf[4096];
    long fd = sys3(56 /*openat*/, -100, (long)"/proc/cmdline", 0);
    if (fd < 0) return;
    long n = sys3(63 /*read*/, fd, (long)buf, sizeof buf - 1);
    sys3(57 /*close*/, fd, 0, 0);
    if (n <= 0) return;
    buf[n] = 0;
    char *p = buf;
    while (*p) {
        while (*p == ' ' || *p == '\n') p++;
        char *tok = p;
        while (*p && *p != ' ' && *p != '\n') p++;
        char save = *p; *p = 0;
        if (tok[0]=='a'&&tok[1]=='n'&&tok[2]=='d'&&tok[3]=='r'&&tok[4]=='o'&&tok[5]=='i'&&tok[6]=='d'&&tok[7]=='b'&&tok[8]=='o'&&tok[9]=='o'&&tok[10]=='t'&&tok[11]=='.') {
            char name[96]; scopy(name, "ro.boot.", sizeof name);
            usize o = slen(name); char *k = tok + 12; char *eq = k;
            while (*eq && *eq != '=') eq++;
            if (*eq == '=') {
                for (char *q = k; q < eq && o + 1 < sizeof name; q++) name[o++] = *q;
                name[o] = 0;
                put(name, eq + 1);
            }
        }
        *p = save;
        if (*p) p++;
    }
}
static int inited;
static void init(void) {
    if (inited) return; inited = 1;
    put("servicemanager.ready", "true");
    put("hwservicemanager.ready", "true");
    put("ro.property_service.version", "2");
    put("ro.baseband", "msm");
    put("ro.arch", "arm64");
    put("ro.build.version.codename", "REL");
    put("ro.hardware", "qcom");
    put("ro.board.platform", "holi");
    put("ro.product.board", "holi");
    put("ro.boot.hardware", "qcom");
    put("ro.debuggable", "0");
    put("ro.product.board", "ibiza");
    import_cmdline();
}

const struct prop_info *__system_property_find(const char *name) { init(); return lookup(name); }
int __system_property_read(const struct prop_info *pi, char *name, char *value) {
    if (name) scopy(name, pi->name, 96);
    scopy(value, pi->value, 92);
    return (int)slen(pi->value);
}
void __system_property_read_callback(const struct prop_info *pi, void (*cb)(void *, const char *, const char *, u32), void *cookie) {
    cb(cookie, pi->name, pi->value, pi->serial);
}
int __system_property_get(const char *name, char *value) {
    init();
    struct prop_info *p = lookup(name);
    if (!p) { value[0] = 0; return 0; }
    scopy(value, p->value, 92);
    return (int)slen(p->value);
}
int __system_property_set(const char *key, const char *value) { init(); return put(key, value) ? 0 : -1; }
u32 __system_property_serial(const struct prop_info *pi) { return pi->serial; }
u32 __system_property_area_serial(void) { return area_serial; }
/* Never return instantly: that is what turned waiting into a 100% CPU spin. */
_Bool __system_property_wait(const struct prop_info *pi, u32 old_serial, u32 *new_serial, const long *timeout) {
    long ms = 100;
    if (timeout) { long t = timeout[0] * 1000 + timeout[1] / 1000000; if (t < ms) ms = t > 0 ? t : 1; }
    nap(0, ms * 1000000L);
    u32 cur = pi ? pi->serial : area_serial;
    if (new_serial) *new_serial = cur;
    return cur != old_serial;
}
u32 __system_property_wait_any(u32 old_serial) { nap(0, 100000000L); return area_serial != old_serial ? area_serial : old_serial + 2; }

/* ---- libselinux stand-ins: there is no SELinux policy in this Debian, so vndservicemanager's access checks would deny
 * every addService. These make the checks pass; they only apply to processes started with LD_PRELOAD=libibizaprop.so. */
static char ctx_buf[64];
static char *give_ctx(char **con, const char *c) { scopy(ctx_buf, c, sizeof ctx_buf); *con = ctx_buf; return ctx_buf; }
int getcon(char **con) { give_ctx(con, "u:r:vndservicemanager:s0"); return 0; }
int getpidcon(int pid, char **con) { (void)pid; give_ctx(con, "u:r:vendor_init:s0"); return 0; }
void freecon(char *con) { (void)con; }
int selabel_lookup(void *hnd, char **con, const char *key, int type) { (void)hnd; (void)key; (void)type; give_ctx(con, "u:object_r:default_android_vndservice:s0"); return 0; }
int selinux_check_access(const char *s, const char *t, const char *c, const char *p, void *aux) { (void)s; (void)t; (void)c; (void)p; (void)aux; return 0; }
int selinux_status_open(int fallback) { (void)fallback; return 0; }
int selinux_status_updated(void) { return 0; }
