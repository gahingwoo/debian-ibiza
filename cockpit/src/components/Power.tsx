/* SPDX-License-Identifier: AGPL-3.0-or-later */

import React, { useState } from "react";
import { Alert } from "@patternfly/react-core/dist/esm/components/Alert/index.js";
import { Button } from "@patternfly/react-core/dist/esm/components/Button/index.js";
import { Card, CardBody, CardHeader, CardTitle } from "@patternfly/react-core/dist/esm/components/Card/index.js";
import { Content } from "@patternfly/react-core/dist/esm/components/Content/index.js";
import { Title } from "@patternfly/react-core/dist/esm/components/Title/index.js";
import { Stack, StackItem } from "@patternfly/react-core/dist/esm/layouts/Stack/index.js";

import { _, asRoot } from "../phone.js";
import { Confirm } from "./Confirm.jsx";

/* Shown only when an Android boot image is on slot A (the page checks /run/ibiza/android): this Linux runs from RAM
 * through fastboot, so a warm reboot returns to Android. */
export function Power({ admin }: { admin: boolean }) {
    const [asking, setAsking] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const reboot = () => {
        setAsking(false);
        setError(null);
        asRoot("sync; echo s > /proc/sysrq-trigger; echo u > /proc/sysrq-trigger; echo b > /proc/sysrq-trigger")
                .catch((e: Error) => setError(e.message));
    };

    return (
        <Card isFullHeight>
            <CardHeader><CardTitle><Title headingLevel="h2" size="lg">{_("Android")}</Title></CardTitle></CardHeader>
            <CardBody>
                <Stack hasGutter>
                    <StackItem>
                        <Content component="p">{_("This system runs from RAM. A reboot returns the phone to Android on slot A.")}</Content>
                    </StackItem>
                    <StackItem>
                        <Button variant="secondary" isDisabled={!admin} onClick={() => setAsking(true)}>{_("Reboot to Android")}</Button>
                    </StackItem>
                    {error && <StackItem><Alert variant="danger" isInline title={_("Could not reboot")}>{error}</Alert></StackItem>}
                </Stack>
            </CardBody>
            <Confirm isOpen={asking} title={_("Reboot to Android?")} action={_("Reboot to Android")} isDanger
                     onConfirm={reboot} onCancel={() => setAsking(false)}>
                {_("The phone restarts into Android and this Debian session ends. Unsaved work here is lost.")}
            </Confirm>
        </Card>
    );
}
