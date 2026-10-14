/* SPDX-License-Identifier: AGPL-3.0-or-later */

import React from "react";
import { Card, CardBody, CardHeader, CardTitle } from "@patternfly/react-core/dist/esm/components/Card/index.js";
import { DescriptionList, DescriptionListDescription, DescriptionListGroup, DescriptionListTerm } from "@patternfly/react-core/dist/esm/components/DescriptionList/index.js";
import { Label } from "@patternfly/react-core/dist/esm/components/Label/index.js";
import { Progress, ProgressMeasureLocation, ProgressVariant } from "@patternfly/react-core/dist/esm/components/Progress/index.js";
import { Title } from "@patternfly/react-core/dist/esm/components/Title/index.js";
import { Flex, FlexItem } from "@patternfly/react-core/dist/esm/layouts/Flex/index.js";
import cockpit from "cockpit";

import { _, type Phone } from "../phone.js";

function Row({ term, children }: { term: string; children: React.ReactNode }) {
    return (
        <DescriptionListGroup>
            <DescriptionListTerm>{term}</DescriptionListTerm>
            <DescriptionListDescription>{children}</DescriptionListDescription>
        </DescriptionListGroup>
    );
}

export function Battery({ phone }: { phone: Phone }) {
    const b = phone.bat;
    const charging = b.status === "Charging";
    // The kernel reports the current as negative while charging.
    const flow = b.current < 0 ? _("into the battery") : _("out of the battery");
    const power = Math.abs(b.current * b.voltage / 1000);
    const variant = b.capacity <= 15 ? ProgressVariant.danger : b.capacity <= 35 ? ProgressVariant.warning : ProgressVariant.success;

    return (
        <Card isFullHeight>
            <CardHeader>
                <CardTitle>
                    <Flex justifyContent={{ default: "justifyContentSpaceBetween" }} alignItems={{ default: "alignItemsCenter" }}>
                        <FlexItem><Title headingLevel="h2" size="lg">{_("Battery")}</Title></FlexItem>
                        <FlexItem>
                            <Label color={charging ? "green" : "blue"} isCompact>
                                {b.status}{b.chargeType && b.chargeType !== "N/A" && charging ? ` (${b.chargeType})` : ""}
                            </Label>
                        </FlexItem>
                    </Flex>
                </CardTitle>
            </CardHeader>
            <CardBody>
                <Progress value={b.capacity} title={_("Charge")} variant={variant} measureLocation={ProgressMeasureLocation.outside}
                          aria-label={_("Battery charge")} />
            </CardBody>
            <CardBody>
                <DescriptionList isCompact isHorizontal aria-label={_("Battery")}>
                    <Row term={_("Voltage")}>{b.voltage.toFixed(3)} V</Row>
                    <Row term={_("Current")}>{Math.abs(b.current).toFixed(0)} mA <span className="phone-detail">{flow}</span></Row>
                    <Row term={_("Power")}>{power.toFixed(2)} W</Row>
                    <Row term={_("Temperature")}>{b.temp.toFixed(1)} °C</Row>
                    <Row term={_("Health")}>{b.health}</Row>
                    <Row term={_("Technology")}>{b.technology}</Row>
                    <Row term={_("USB charger")}>
                        {phone.usbOnline ? cockpit.format(_("Connected, $0 V"), phone.usbVolts.toFixed(2)) : _("Not connected")}
                    </Row>
                </DescriptionList>
                <div className="phone-detail">{_("The charge limit register is read-only on this kernel, so charging cannot be capped.")}</div>
            </CardBody>
        </Card>
    );
}
