/* SPDX-License-Identifier: AGPL-3.0-or-later */

import { useCallback, useEffect, useState } from "react";
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
