/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.plasma.plasma5support as Plasma5Support

/*
 * Runs one flatpak install at a time and reports the result back into the model.
 *
 * Sequential rather than parallel: flatpak takes a lock on the user installation, so a
 * second install would only sit and wait, and one progress line at a time is easier to
 * follow from a couch anyway.
 */
QtObject {
    id: installer

    /* Model of app entries. Each row carries a status of pending, running, done or failed. */
    property var model: null

    property bool running: false
    property int currentIndex: -1
    property int failures: 0

    signal finished()

    readonly property var source: Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: []

        onNewData: (source, data) => {
            disconnectSource(source);

            const failed = data["exit code"] !== 0;

            installer.model.setProperty(installer.currentIndex, "status", failed ? "failed" : "done");
            if (failed) {
                installer.model.setProperty(installer.currentIndex, "error", String(data["stderr"]).trim());
                installer.failures += 1;
            }

            installer.next();
        }
    }

    function start() {
        if (running) {
            return;
        }

        running = true;
        failures = 0;
        currentIndex = -1;
        next();
    }

    function next() {
        for (let i = currentIndex + 1; i < model.count; i++) {
            if (model.get(i).selected) {
                currentIndex = i;
                model.setProperty(i, "status", "running");
                // --noninteractive answers the remote and dependency prompts, which have
                // nothing to answer them on a screen with no keyboard.
                source.connectSource("flatpak install --user --noninteractive --or-update flathub " + model.get(i).appId);
                return;
            }
        }

        currentIndex = -1;
        running = false;
        finished();
    }
}
