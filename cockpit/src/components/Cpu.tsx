/* SPDX-License-Identifier: AGPL-3.0-or-later */

import React, { useState } from "react";
import { Alert } from "@patternfly/react-core/dist/esm/components/Alert/index.js";
import { Card, CardBody, CardHeader, CardTitle } from "@patternfly/react-core/dist/esm/components/Card/index.js";
import { FormSelect, FormSelectOption } from "@patternfly/react-core/dist/esm/components/FormSelect/index.js";
import { Progress } from "@patternfly/react-core/dist/esm/components/Progress/index.js";
import { Title } from "@patternfly/react-core/dist/esm/components/Title/index.js";
import { Flex, FlexItem } from "@patternfly/react-core/dist/esm/layouts/Flex/index.js";
import { Stack, StackItem } from "@patternfly/react-core/dist/esm/layouts/Stack/index.js";
import cockpit from "cockpit";

import { _, asRoot, type Phone, type Policy } from "../phone.js";

const mhz = (khz: number) => cockpit.format(_("$0 MHz"), Math.round(khz / 1000));

/* The CPUs are two clusters, each its own cpufreq policy. */
function cores(p: Policy): string {
    const n = p.cpus.trim().split(/\s+/).map(Number);
    return n.length > 1 ? cockpit.format(_("Cores $0–$1"), n[0], n[n.length - 1]) : cockpit.format(_("Core $0"), n[0]);
}

export function Cpu({ phone, admin, refresh }: { phone: Phone; admin: boolean; refresh: () => void }) {
    const [error, setError] = useState<string | null>(null);

    const setGovernor = (policy: string, governor: string) => {
        setError(null);
        asRoot('echo "$2" > /sys/devices/system/cpu/cpufreq/$1/scaling_governor', [policy, governor])
                .catch((e: Error) => setError(e.message))
                .finally(refresh);
    };

    return (
        <Card isFullHeight>
            <CardHeader><CardTitle><Title headingLevel="h2" size="lg">{_("CPU frequency")}</Title></CardTitle></CardHeader>
            <CardBody>
                <Stack hasGutter>
                    {phone.policies.map(p => (
                        <StackItem key={p.name}>
                            <Flex justifyContent={{ default: "justifyContentSpaceBetween" }} alignItems={{ default: "alignItemsCenter" }}>
                                <FlexItem><Title headingLevel="h3" size="md">{cores(p)}</Title></FlexItem>
                                <FlexItem>
                                    <FormSelect value={p.gov} isDisabled={!admin} aria-label={cockpit.format(_("Governor for $0"), cores(p))}
                                                onChange={(_e, v) => setGovernor(p.name, v)}>
                                        {p.govs.map(g => <FormSelectOption key={g} value={g} label={g} />)}
                                    </FormSelect>
                                </FlexItem>
                            </Flex>
                            <Progress value={(p.cur - p.min) / Math.max(1, p.max - p.min) * 100} size="sm" title={_("Frequency")}
                                      label={mhz(p.cur)} valueText={mhz(p.cur)}
                                      aria-label={cockpit.format(_("Frequency of $0"), cores(p))} />
                            <div className="phone-detail">{cockpit.format(_("Range $0 to $1"), mhz(p.min), mhz(p.max))}</div>
                        </StackItem>
                    ))}
                    {error && <StackItem><Alert variant="danger" isInline title={_("Could not change the governor")}>{error}</Alert></StackItem>}
                </Stack>
            </CardBody>
        </Card>
    );
}
