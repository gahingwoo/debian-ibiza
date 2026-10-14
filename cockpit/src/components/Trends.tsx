/* SPDX-License-Identifier: AGPL-3.0-or-later */

import React from "react";
import { Card, CardBody, CardHeader, CardTitle } from "@patternfly/react-core/dist/esm/components/Card/index.js";
import { Title } from "@patternfly/react-core/dist/esm/components/Title/index.js";
import { Grid, GridItem } from "@patternfly/react-core/dist/esm/layouts/Grid/index.js";

import { _, type Phone } from "../phone.js";
import type { Sample } from "../hooks.js";

type Series = { label: string; color: string; values: number[] };

const W = 400;
const H = 130;
const PAD = { l: 38, r: 8, t: 8, b: 20 };

/* A small line chart over the sample window. Plain SVG: the data is at most 720 points, so no chart library is needed. */
function Chart({ title, unit, series, times, min, max, digits = 0 }: {
    title: string; unit: string; series: Series[]; times: number[]; min?: number; max?: number; digits?: number;
}) {
    const all = series.flatMap(s => s.values).filter(v => Number.isFinite(v));
    let lo = min ?? (all.length ? Math.min(...all) : 0);
    let hi = max ?? (all.length ? Math.max(...all) : 1);
    if (min === undefined) lo = Math.floor(lo - (hi - lo) * 0.1 - 0.5);
    if (max === undefined) hi = Math.ceil(hi + (hi - lo) * 0.1 + 0.5);
    if (hi <= lo) hi = lo + 1;

    const t0 = times.length ? times[0] : 0;
    const t1 = times.length ? times[times.length - 1] : 1;
    const x = (t: number) => PAD.l + ((t - t0) / Math.max(1, t1 - t0)) * (W - PAD.l - PAD.r);
    const y = (v: number) => PAD.t + (1 - (v - lo) / (hi - lo)) * (H - PAD.t - PAD.b);
    const line = (vals: number[]) => vals.map((v, i) => `${i ? "L" : "M"}${x(times[i]).toFixed(1)},${y(v).toFixed(1)}`).join("");
    const mins = Math.round((t1 - t0) / 60000);

    return (
        <div className="phone-chart">
            <div className="phone-chart-head">
                <span className="phone-chart-title">{title}</span>
                <span className="phone-chart-legend">
                    {series.map(s => (
                        <span key={s.label} className="phone-chart-key">
                            <i style={{ background: s.color }} />{s.label}
                            <b>{s.values.length ? s.values[s.values.length - 1].toFixed(digits) : "–"} {unit}</b>
                        </span>
                    ))}
                </span>
            </div>
            <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label={title} preserveAspectRatio="none">
                {[0, 0.5, 1].map(f => {
                    const v = lo + (hi - lo) * f;
                    return (
                        <g key={f}>
                            <line x1={PAD.l} x2={W - PAD.r} y1={y(v)} y2={y(v)} className="phone-chart-grid" />
                            <text x={PAD.l - 4} y={y(v) + 3} textAnchor="end" className="phone-chart-axis">{v.toFixed(digits)}</text>
                        </g>
                    );
                })}
                {lo < 0 && hi > 0 && <line x1={PAD.l} x2={W - PAD.r} y1={y(0)} y2={y(0)} className="phone-chart-zero" />}
                {times.length > 1 && series.map(s => (
                    <g key={s.label}>
                        {series.length === 1 &&
                            <path d={`${line(s.values)}L${x(t1).toFixed(1)},${y(Math.max(lo, 0 < lo ? lo : 0)).toFixed(1)}L${x(t0).toFixed(1)},${y(Math.max(lo, 0 < lo ? lo : 0)).toFixed(1)}Z`}
                                  fill={s.color} opacity="0.15" />}
                        <path d={line(s.values)} fill="none" stroke={s.color} strokeWidth="1.8" vectorEffect="non-scaling-stroke" />
                    </g>
                ))}
                <text x={PAD.l} y={H - 5} className="phone-chart-axis">{mins > 0 ? `-${mins} min` : ""}</text>
                <text x={W - PAD.r} y={H - 5} textAnchor="end" className="phone-chart-axis">{_("now")}</text>
            </svg>
        </div>
    );
}

const BLUE = "var(--pf-t--chart--color--blue--300, #2b9af3)";
const GREEN = "var(--pf-t--chart--color--green--300, #6ec664)";
const ORANGE = "var(--pf-t--chart--color--orange--300, #ef9234)";
const PURPLE = "var(--pf-t--chart--color--purple--300, #8481dd)";
const RED = "var(--pf-t--chart--color--red-orange--300, #f4784a)";

export function Trends({ phone, samples }: { phone: Phone; samples: Sample[] }) {
    const times = samples.map(s => s.t);
    const maxFreq = (i: number) => (phone.policies[i]?.max ?? 2000000) / 1000;
    const memTotal = Math.round(phone.memTotal / 1048576);
    // Scale to what is actually used: against the full 7.4 GB the line would sit flat on the floor.
    const memMax = Math.max(256, Math.ceil(Math.max(0, ...samples.map(s => s.mem)) * 1.4 / 128) * 128);
    return (
        <Card isFullHeight>
            <CardHeader><CardTitle><Title headingLevel="h2" size="lg">{_("Last hour")}</Title></CardTitle></CardHeader>
            <CardBody>
                <Grid hasGutter md={6} xl={3}>
                    <GridItem>
                        <Chart title={_("SoC temperature")} unit="°C" times={times} digits={1}
                               series={[{ label: _("hottest core"), color: RED, values: samples.map(s => s.temp) }]} />
                    </GridItem>
                    <GridItem>
                        <Chart title={_("CPU frequency")} unit="MHz" times={times} min={0} max={Math.max(maxFreq(0), maxFreq(1))}
                               series={[
                                   { label: "0–5", color: BLUE, values: samples.map(s => s.little) },
                                   { label: "6–7", color: ORANGE, values: samples.map(s => s.big) },
                               ]} />
                    </GridItem>
                    <GridItem>
                        <Chart title={_("Battery power")} unit="W" times={times} digits={2}
                               series={[{ label: _("into battery"), color: GREEN, values: samples.map(s => s.watts) }]} />
                    </GridItem>
                    <GridItem>
                        <Chart title={_("Memory used")} unit="MB" times={times} min={0} max={memMax}
                               series={[{ label: `/ ${memTotal} MB`, color: PURPLE, values: samples.map(s => s.mem) }]} />
                    </GridItem>
                </Grid>
            </CardBody>
        </Card>
    );
}
