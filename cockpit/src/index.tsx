/* SPDX-License-Identifier: AGPL-3.0-or-later */

import React from 'react';
import { createRoot } from 'react-dom/client';

import "cockpit-dark-theme";

import { Application } from './app.jsx';

import "patternfly/patternfly-6-cockpit.scss";
import './app.scss';

document.addEventListener("DOMContentLoaded", () => {
    createRoot(document.getElementById("app")!).render(<Application />);
});
