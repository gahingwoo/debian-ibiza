/*
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * The Moto G50 running Debian, in Cockpit: device, battery, CPU, temperatures, and a reboot back to Android when
 * Android is on the phone. Everything is read from sysfs through one script; see phone.ts.
 */

import React from "react";
import { Alert } from "@patternfly/react-core/dist/esm/components/Alert/index.js";
import { EmptyState } from "@patternfly/react-core/dist/esm/components/EmptyState/index.js";
import { Page, PageSection } from "@patternfly/react-core/dist/esm/components/Page/index.js";
import { Spinner } from "@patternfly/react-core/dist/esm/components/Spinner/index.js";
import { Grid, GridItem } from "@patternfly/react-core/dist/esm/layouts/Grid/index.js";
import { Stack, StackItem } from "@patternfly/react-core/dist/esm/layouts/Stack/index.js";

import { _ } from "./phone.js";
import { useAdmin, usePhone } from "./hooks.js";
import { Battery } from "./components/Battery.jsx";
import { Cpu } from "./components/Cpu.jsx";
import { Device } from "./components/Device.jsx";
import { Power } from "./components/Power.jsx";
import { Thermal } from "./components/Thermal.jsx";

export const Application = () => {
    const admin = useAdmin();
    const { phone, error, refresh } = usePhone();

    let body: React.ReactNode;
    if (!phone) {
        body = error
            ? <Alert variant="danger" isInline title={_("Could not read the phone's status")}>{error}</Alert>
            : <EmptyState titleText={_("Loading")} headingLevel="h2" icon={Spinner} />;
    } else {
        body = (
            <Stack hasGutter>
                {!admin &&
                    <StackItem>
                        <Alert variant="info" isInline title={_("Turn on administrative access to change the CPU governor or reboot.")} />
                    </StackItem>}
                <StackItem>
                    <Grid hasGutter>
                        <GridItem md={6} xl={4}><Device phone={phone} /></GridItem>
                        <GridItem md={6} xl={4}><Battery phone={phone} /></GridItem>
                        <GridItem md={6} xl={4}><Cpu phone={phone} admin={admin} refresh={refresh} /></GridItem>
                        <GridItem md={6} xl={8}><Thermal phone={phone} /></GridItem>
                        {phone.android &&
                            <GridItem md={6} xl={4}><Power admin={admin} /></GridItem>}
                    </Grid>
                </StackItem>
            </Stack>
        );
    }

    return (
        <Page className="ct-page-fill" isContentFilled>
            <PageSection>{body}</PageSection>
        </Page>
    );
};
