/* SPDX-License-Identifier: AGPL-3.0-or-later */

import { useCallback, useEffect, useState } from "react";
import cockpit from "cockpit";
import { superuser } from "superuser.js";

import { readPhone, type Phone } from "./phone.js";

const POLL_MS = 5000;

/** Whether Cockpit's administrative access is on, as it changes. */
export function useAdmin(): boolean {
    const [allowed, setAllowed] = useState<boolean>(superuser.allowed === true);
    useEffect(() => {
        const changed = () => setAllowed(superuser.allowed === true);
        superuser.addEventListener("changed", changed);
        return () => superuser.removeEventListener("changed", changed);
    }, []);
    return allowed;
}

/** The phone's readings, now and every five seconds after. */
export function usePhone() {
    const [phone, setPhone] = useState<Phone | null>(null);
    const [error, setError] = useState<string | null>(null);

    const refresh = useCallback(() => {
        readPhone()
                .then(p => { setPhone(p); setError(null) })
                .catch((e: Error) => setError(e.message));
    }, []);

    useEffect(() => {
        refresh();
        const timer = window.setInterval(refresh, POLL_MS);
        return () => window.clearInterval(timer);
    }, [refresh]);

    return { phone, error, refresh };
}

export type Sample = { t: number; temp: number; little: number; big: number; watts: number; mem: number };
const HISTORY = "/run/ibiza/history.tsv";

/** The last hour of samples written by ibiza-history.service, updated as the file grows. */
export function useHistory(): Sample[] {
    const [samples, setSamples] = useState<Sample[]>([]);
    useEffect(() => {
        const file = cockpit.file(HISTORY);
        file.watch((content: string | null) => {
            const rows: Sample[] = [];
            for (const line of (content ?? "").split("\n")) {
                const f = line.split("\t");
                if (f.length < 6) continue;
                rows.push({ t: Number(f[0]), temp: Number(f[1]), little: Number(f[2]), big: Number(f[3]), watts: Number(f[4]), mem: Number(f[5]) });
            }
            setSamples(rows);
        }, { read: true });
        return () => file.close();
    }, []);
    return samples;
}
