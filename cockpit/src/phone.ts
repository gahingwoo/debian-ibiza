/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * What the Moto G50 reports about itself. One shell script reads sysfs/procfs on the host and prints key=value
 * lines (policy| and thermal| lines for lists); parse() turns them into Phone. No privileges are needed to read.
 */

import cockpit from "cockpit";

export const _ = cockpit.gettext;

export type Policy = { name: string; gov: string; cur: number; min: number; max: number; cpus: string; govs: string[] };
export type Zone = { type: string; t: number };
export type Phone = {
    model: string; soc: string; serial: string; bootloader: string; kernel: string;
    uptime: number; load: string;
    memTotal: number; memAvail: number; diskUsed: number; diskTotal: number;
    addresses: { dev: string; addr: string }[];
    bat: { status: string; capacity: number; voltage: number; current: number; temp: number;
           health: string; technology: string; chargeType: string };
    usbOnline: boolean; usbVolts: number;
    policies: Policy[]; thermal: Zone[];
    android: boolean;
};

const COLLECT = [
    'f=/etc/ibiza/fake-dmi.txt',
    'g(){ sed -n "s|^/sys/class/dmi/id/$1:||p" $f 2>/dev/null | head -n 1; }',
    'echo "model=$(g product_name)"; echo "serial=$(g product_serial)"; echo "bios=$(g bios_version)"; echo "soc=$(g board_name)"',
    'echo "kernel=$(uname -r)"; echo "uptime=$(cut -d" " -f1 /proc/uptime)"; echo "load=$(cut -d" " -f1-3 /proc/loadavg)"',
    'echo "mem_total=$(awk \'/^MemTotal/{print $2}\' /proc/meminfo)"; echo "mem_avail=$(awk \'/^MemAvailable/{print $2}\' /proc/meminfo)"',
    'echo "disk=$(df -k / | awk \'NR==2{print $3" "$2}\')"',
    'b=/sys/class/power_supply/qcom_battery',
    'for a in status capacity voltage_now current_now temp health technology charge_type; do echo "bat_$a=$(cat $b/$a 2>/dev/null)"; done',
    'echo "usb_online=$(cat /sys/class/power_supply/usb/online 2>/dev/null)"; echo "usb_v=$(cat /sys/class/power_supply/usb/voltage_now 2>/dev/null)"',
    'for p in /sys/devices/system/cpu/cpufreq/policy*; do echo "policy|$(basename $p)|$(cat $p/scaling_governor)|$(cat $p/scaling_cur_freq)|$(cat $p/scaling_min_freq)|$(cat $p/scaling_max_freq)|$(cat $p/related_cpus)|$(cat $p/scaling_available_governors)"; done',
    'for z in /sys/class/thermal/thermal_zone*; do t=$(cat $z/temp 2>/dev/null); case "$t" in ""|*[!0-9-]*) ;; *) echo "thermal|$(cat $z/type)|$t";; esac; done',
    'echo "ip=$(ip -4 -o addr show 2>/dev/null | awk \'$2!="lo"{print $2"="$4}\' | tr "\\n" " ")"',
    'echo "android=$([ -e /run/ibiza/android ] && echo 1 || echo 0)"',
].join("\n");

function parse(out: string): Phone {
    const kv: Record<string, string> = {};
    const policies: Policy[] = [];
    const thermal: Zone[] = [];
    for (const line of out.split("\n")) {
        if (line.startsWith("policy|")) {
            const p = line.split("|");
            policies.push({ name: p[1], gov: p[2], cur: Number(p[3]), min: Number(p[4]), max: Number(p[5]), cpus: p[6], govs: (p[7] ?? "").trim().split(/\s+/) });
        } else if (line.startsWith("thermal|")) {
            const p = line.split("|");
            thermal.push({ type: p[1], t: Number(p[2]) / 1000 });
        } else {
            const i = line.indexOf("=");
            if (i > 0) kv[line.slice(0, i)] = line.slice(i + 1);
        }
    }
    const [diskUsed, diskTotal] = (kv.disk ?? "0 0").split(" ").map(Number);
    return {
        model: kv.model ?? "", soc: kv.soc ?? "", serial: kv.serial ?? "", bootloader: kv.bios ?? "", kernel: kv.kernel ?? "",
        uptime: Number(kv.uptime), load: kv.load ?? "",
        memTotal: Number(kv.mem_total) * 1024, memAvail: Number(kv.mem_avail) * 1024,
        diskUsed: diskUsed * 1024, diskTotal: diskTotal * 1024,
        addresses: (kv.ip ?? "").trim().split(/\s+/).filter(Boolean).map(s => { const [dev, addr] = s.split("="); return { dev, addr }; }),
        bat: {
            status: kv.bat_status ?? "", capacity: Number(kv.bat_capacity), voltage: Number(kv.bat_voltage_now) / 1e6,
            current: Number(kv.bat_current_now) / 1000, temp: Number(kv.bat_temp) / 10,
            health: kv.bat_health ?? "", technology: kv.bat_technology ?? "", chargeType: kv.bat_charge_type ?? "",
        },
        usbOnline: kv.usb_online === "1", usbVolts: Number(kv.usb_v) / 1e6,
        policies, thermal,
        android: kv.android === "1",
    };
}

export function readPhone(): Promise<Phone> {
    return cockpit.script(COLLECT, [], { err: "message" }).then(parse);
}

/** Run a command as root (needs Cockpit's administrative access). Arguments reach the script as $1, $2, ... */
export function asRoot(script: string, args: string[] = []): Promise<string> {
    return cockpit.spawn(["sh", "-c", script, "sh", ...args], { superuser: "require", err: "message" });
}
