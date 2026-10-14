/* SPDX-License-Identifier: AGPL-3.0-or-later */

import React from "react";
import { Card, CardBody, CardHeader, CardTitle } from "@patternfly/react-core/dist/esm/components/Card/index.js";
import { Label } from "@patternfly/react-core/dist/esm/components/Label/index.js";
import { Title } from "@patternfly/react-core/dist/esm/components/Title/index.js";
import { Flex, FlexItem } from "@patternfly/react-core/dist/esm/layouts/Flex/index.js";
import { Grid, GridItem } from "@patternfly/react-core/dist/esm/layouts/Grid/index.js";

import { _, type Phone } from "../phone.js";

/* The hottest sensors first. Many thermal zones are the same chip twice (-usr and -step), so they are shown as
 * they come rather than merged. */
export function Thermal({ phone }: { phone: Phone }) {
    const zones = phone.thermal.filter(z => z.t > 0 && z.t < 150).sort((a, b) => b.t - a.t).slice(0, 12);
    return (
        <Card isFullHeight>
            <CardHeader><CardTitle><Title headingLevel="h2" size="lg">{_("Temperatures")}</Title></CardTitle></CardHeader>
            <CardBody>
                <Grid hasGutter md={6} xl={3}>
                    {zones.map(z => (
                        <GridItem key={z.type}>
                            <Flex justifyContent={{ default: "justifyContentSpaceBetween" }} flexWrap={{ default: "nowrap" }}>
                                <FlexItem>{z.type}</FlexItem>
                                <FlexItem>
                                    <Label isCompact color={z.t >= 70 ? "red" : z.t >= 50 ? "orange" : "green"}>{z.t.toFixed(1)} °C</Label>
                                </FlexItem>
                            </Flex>
                        </GridItem>
                    ))}
                </Grid>
            </CardBody>
        </Card>
    );
}
