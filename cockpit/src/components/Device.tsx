/* SPDX-License-Identifier: AGPL-3.0-or-later */

import React from "react";
import { Card, CardBody, CardHeader, CardTitle } from "@patternfly/react-core/dist/esm/components/Card/index.js";
import { DescriptionList, DescriptionListDescription, DescriptionListGroup, DescriptionListTerm } from "@patternfly/react-core/dist/esm/components/DescriptionList/index.js";
import { Label, LabelGroup } from "@patternfly/react-core/dist/esm/components/Label/index.js";
import { Progress } from "@patternfly/react-core/dist/esm/components/Progress/index.js";
import { Title } from "@patternfly/react-core/dist/esm/components/Title/index.js";
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

function uptime(seconds: number): string {
    const d = Math.floor(seconds / 86400);
    const h = Math.floor(seconds % 86400 / 3600);
    const m = Math.floor(seconds % 3600 / 60);
    return (d ? cockpit.format(_("$0 d "), d) : "") + cockpit.format(_("$0 h $1 min"), h, m);
}

export function Device({ phone }: { phone: Phone }) {
    const memUsed = phone.memTotal - phone.memAvail;
    return (
        <Card isFullHeight>
            <CardHeader><CardTitle><Title headingLevel="h2" size="lg">{_("Device")}</Title></CardTitle></CardHeader>
            <CardBody>
                <DescriptionList isCompact isHorizontal aria-label={_("Device")}>
                    <Row term={_("Model")}>{phone.model}</Row>
                    <Row term={_("SoC")}>{phone.soc}</Row>
                    <Row term={_("Serial number")}>{phone.serial}</Row>
                    <Row term={_("Bootloader")}>{phone.bootloader}</Row>
                    <Row term={_("Kernel")}>{phone.kernel}</Row>
                    <Row term={_("Uptime")}>{uptime(phone.uptime)}</Row>
                    <Row term={_("Load average")}>{phone.load}</Row>
                    <Row term={_("Network")}>
                        <LabelGroup>
                            {phone.addresses.map(a => <Label key={a.dev + a.addr} isCompact>{a.dev} {a.addr}</Label>)}
                        </LabelGroup>
                    </Row>
                </DescriptionList>
            </CardBody>
            <CardBody>
                <Progress value={memUsed / phone.memTotal * 100} title={_("Memory")} size="sm"
                          label={cockpit.format(_("$0 of $1"), cockpit.format_bytes(memUsed), cockpit.format_bytes(phone.memTotal))}
                          valueText={cockpit.format_bytes(memUsed)} aria-label={_("Memory used")} />
            </CardBody>
            <CardBody>
                <Progress value={phone.diskUsed / phone.diskTotal * 100} title={_("Root disk")} size="sm"
                          label={cockpit.format(_("$0 of $1"), cockpit.format_bytes(phone.diskUsed), cockpit.format_bytes(phone.diskTotal))}
                          valueText={cockpit.format_bytes(phone.diskUsed)} aria-label={_("Root disk used")} />
            </CardBody>
        </Card>
    );
}
