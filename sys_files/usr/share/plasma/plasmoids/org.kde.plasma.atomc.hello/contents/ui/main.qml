/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.bigscreen as Bigscreen

import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    fullRepresentation: FocusScope {
        id: screen

        Kirigami.Theme.colorSet: Kirigami.Theme.View
        Kirigami.Theme.inherit: false

        implicitWidth: Kirigami.Units.gridUnit * 50
        implicitHeight: Kirigami.Units.gridUnit * 34

        focus: true

        readonly property bool picking: !installer.running && installer.currentIndex === -1 && !finished
        property bool finished: false

        ListModel {
            id: appModel
        }

        Installer {
            id: installer
            model: appModel
            onFinished: screen.finished = true
        }

        Plasma5Support.DataSource {
            id: runner
            engine: "executable"
            connectedSources: []
            onNewData: source => {
                disconnectSource(source);
                screen.close();
            }
        }

        // The stamp is written by a child process, so closing the window straight away can
        // take the process down with it. This is the way out if the engine never reports
        // back at all.
        Timer {
            id: dismissTimeout
            interval: 5000
            onTriggered: screen.close()
        }

        Component.onCompleted: {
            const request = new XMLHttpRequest();
            request.open("GET", "file:///usr/share/atomc/recommended-apps.json");
            request.onreadystatechange = () => {
                if (request.readyState !== XMLHttpRequest.DONE) {
                    return;
                }

                let apps = [];
                try {
                    apps = JSON.parse(request.responseText).apps;
                } catch (error) {
                    console.warn("atomc-hello: cannot read the recommended app list:", error);
                }

                for (const app of apps) {
                    appModel.append({
                        appId: app.id,
                        name: app.name,
                        summary: app.description ?? "",
                        iconName: app.icon ?? "application-x-executable",
                        selected: app.default === true,
                        status: "pending",
                        error: ""
                    });
                }

                if (appRepeater.count > 0) {
                    appRepeater.itemAt(0).forceActiveFocus();
                } else {
                    skipButton.forceActiveFocus();
                }
            };
            request.send();
        }

        /* Written whatever the user chose, including nothing, so the screen is shown once. */
        function dismiss() {
            dismissTimeout.start();
            runner.connectSource("/usr/libexec/atomc/atomc-hello-done");
        }

        // Qt.quit() does nothing here: the applet is loaded into plasmawindowed, whose engine
        // has no receiver for the quit signal, so the window has to be closed directly.
        function close() {
            dismissTimeout.stop();
            const window = screen.Window.window;
            if (window) {
                window.close();
            } else {
                Qt.quit();
            }
        }

        // The plasmoid is windowed, so it paints its own ground rather than sitting on the
        // homescreen wallpaper.
        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.darker(Kirigami.Theme.backgroundColor, 1.25) }
                GradientStop { position: 1.0; color: Kirigami.Theme.backgroundColor }
            }

            // A wash of the accent colour behind the header, so the top of the screen is
            // not a flat slab.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -height / 2
                width: parent.width * 1.2
                height: parent.height * 0.9
                radius: width / 2
                opacity: 0.18

                gradient: Gradient {
                    GradientStop { position: 0.0; color: Kirigami.Theme.highlightColor }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: Kirigami.Units.gridUnit * 2
            }
            spacing: Kirigami.Units.gridUnit

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("Welcome to AtoMC")
                    font.pixelSize: Bigscreen.Units.defaultFontPixelSize * 2.2
                    font.weight: Font.Light
                    elide: Text.ElideRight
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: screen.finished
                        ? (installer.failures > 0
                            ? i18n("Some applications could not be installed.")
                            : i18n("All set. These are on the homescreen now."))
                        : (installer.running
                            ? i18n("Installing. This can take a few minutes.")
                            : i18n("Pick the applications to install. Everything here can be removed later, and anything missing can be added from Bazaar."))
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: Bigscreen.Units.defaultFontPixelSize
                    wrapMode: Text.Wrap
                }
            }

            // A Repeater in a column rather than a ListView. Bigscreen navigates by moving
            // real active focus between items with KeyNavigation, and a ListView moves a
            // currentIndex instead, which leaves the delegates unfocused and the arrow keys
            // doing nothing visible.
            ColumnLayout {
                id: appColumn

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop

                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    id: appRepeater

                    model: appModel

                    delegate: Bigscreen.SwitchDelegate {
                        id: appDelegate

                        required property int index
                        required property string appId
                        required property string name
                        required property string summary
                        required property string iconName
                        required property bool selected
                        required property string status
                        required property string error

                        Layout.fillWidth: true

                        text: name
                        description: {
                            switch (appDelegate.status) {
                            case "running":
                                return i18n("Installing...");
                            case "done":
                                return i18n("Installed");
                            case "failed":
                                return appDelegate.error === "" ? i18n("Failed") : i18n("Failed: %1", appDelegate.error);
                            default:
                                return appDelegate.summary;
                            }
                        }
                        icon.name: {
                            switch (appDelegate.status) {
                            case "done":
                                return "dialog-ok";
                            case "failed":
                                return "dialog-error";
                            default:
                                return appDelegate.iconName;
                            }
                        }

                        checked: appDelegate.selected
                        enabled: screen.picking

                        KeyNavigation.up: index > 0 ? appRepeater.itemAt(index - 1) : null
                        KeyNavigation.down: index < appRepeater.count - 1
                            ? appRepeater.itemAt(index + 1)
                            : (installButton.visible ? installButton : skipButton)

                        onToggled: appModel.setProperty(index, "selected", checked)

                        // Each row arrives a beat after the one above it, so the list reads
                        // as sliding in rather than appearing.
                        SequentialAnimation on x {
                            PauseAnimation {
                                duration: Kirigami.Units.longDuration * appDelegate.index
                            }
                            NumberAnimation {
                                from: Kirigami.Units.gridUnit * 3
                                to: 0
                                duration: Kirigami.Units.longDuration * 2
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                QQC2.BusyIndicator {
                    running: installer.running
                    visible: running
                    implicitWidth: Kirigami.Units.iconSizes.medium
                    implicitHeight: Kirigami.Units.iconSizes.medium
                }

                Item {
                    Layout.fillWidth: true
                }

                Bigscreen.Button {
                    id: skipButton

                    text: screen.finished ? i18n("Close") : i18n("Not now")
                    visible: !installer.running

                    KeyNavigation.up: appRepeater.count > 0 ? appRepeater.itemAt(appRepeater.count - 1) : null
                    KeyNavigation.right: installButton

                    onClicked: screen.dismiss()
                }

                Bigscreen.Button {
                    id: installButton

                    text: i18n("Install selected")
                    visible: screen.picking
                    enabled: {
                        for (let i = 0; i < appModel.count; i++) {
                            if (appModel.get(i).selected) {
                                return true;
                            }
                        }
                        return false;
                    }

                    KeyNavigation.up: appRepeater.count > 0 ? appRepeater.itemAt(appRepeater.count - 1) : null
                    KeyNavigation.left: skipButton

                    onClicked: installer.start()
                }
            }
        }
    }
}
