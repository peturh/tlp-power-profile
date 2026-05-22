import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: settings
    pluginId: "tlpPowerProfile"

    Component.onCompleted: {
        TlpService.refresh()
    }

    StyledText {
        text: "TLP Power Profile"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledRect {
        width: parent.width
        height: generalCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: generalCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingL
            anchors.topMargin: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "General"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            SliderSetting {
                settingKey: "pollIntervalMs"
                label: "Poll interval"
                description: "How often to read TLP state. Lower = more responsive, higher = lighter on CPU."
                defaultValue: 5000
                minimum: 1000
                maximum: 30000
                unit: "ms"
            }

            SelectionSetting {
                settingKey: "privilegeMode"
                label: "Privilege mode"
                description: "How profile commands are escalated. pkexec uses polkit; sudo -n uses a passwordless sudoers entry; none assumes the user is already root."
                defaultValue: "pkexec"
                options: [
                    { label: "pkexec",     value: "pkexec" },
                    { label: "sudo -n",    value: "sudo" },
                    { label: "None (raw)", value: "none" }
                ]
            }
        }
    }

    StyledRect {
        width: parent.width
        height: profilesCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: profilesCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingL
            anchors.topMargin: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Power profiles"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            StyledText {
                text: "Each profile is a command run when its button is clicked. The privilege prefix (pkexec / sudo) is prepended automatically."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.WordWrap
            }

            ListSetting {
                id: profileList
                settingKey: "profiles"
                label: ""
                defaultValue: [
                    { "id": "power_save",  "label": "Power Save",  "icon": "🍃", "command": "tlp bat" },
                    { "id": "balanced",    "label": "Balanced",    "icon": "⚖️", "command": "tlp ac" },
                    { "id": "performance", "label": "Performance", "icon": "⚡", "command": "tlp-power-profile-helper performance" }
                ]

                function updateField(index, field, value) {
                    const next = profileList.items.slice()
                    next[index] = Object.assign({}, next[index], { [field]: value })
                    profileList.items = next
                }

                delegate: Component {
                    StyledRect {
                        id: row
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: rowCol.height + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                        Column {
                            id: rowCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            anchors.topMargin: Theme.spacingM
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankTextField {
                                    id: iconField
                                    width: 80
                                    text: row.modelData.icon || ""
                                    placeholderText: "🍃"
                                    onEditingFinished: profileList.updateField(row.index, "icon", text)
                                    onActiveFocusChanged: if (!activeFocus) profileList.updateField(row.index, "icon", text)
                                }

                                DankTextField {
                                    width: parent.width - iconField.width - removeBtn.width - parent.spacing * 2
                                    text: row.modelData.label || ""
                                    placeholderText: "Profile name"
                                    onEditingFinished: profileList.updateField(row.index, "label", text)
                                    onActiveFocusChanged: if (!activeFocus) profileList.updateField(row.index, "label", text)
                                }

                                Rectangle {
                                    id: removeBtn
                                    width: 80
                                    height: iconField.height
                                    radius: Theme.cornerRadius
                                    color: removeArea.containsMouse ? Theme.errorHover : Theme.error

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "Remove"
                                        color: Theme.errorText
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                    }

                                    MouseArea {
                                        id: removeArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: profileList.removeItem(row.index)
                                    }
                                }
                            }

                            DankTextField {
                                width: parent.width
                                text: row.modelData.command || ""
                                placeholderText: "tlp ac"
                                onEditingFinished: profileList.updateField(row.index, "command", text)
                                onActiveFocusChanged: if (!activeFocus) profileList.updateField(row.index, "command", text)
                            }
                        }
                    }
                }
            }

            DankButton {
                text: "Add profile"
                iconName: "add"
                onClicked: {
                    profileList.addItem({
                        "id": "profile_" + Date.now(),
                        "label": "New profile",
                        "icon": "bolt",
                        "command": "tlp ac"
                    })
                }
            }
        }
    }

    StyledRect {
        width: parent.width
        visible: BatteryService.batteryAvailable
        height: visible ? thresholdCol.implicitHeight + Theme.spacingL * 2 : 0
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: thresholdCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingL
            anchors.topMargin: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Charge thresholds"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            StyledText {
                text: {
                    let parts = ["TLP enforces these via sysfs. Stop must be at least 4 greater than start."]
                    if (TlpService.currentChargeStart >= 0 && TlpService.currentChargeStop >= 0) {
                        parts.push("Currently active: " + TlpService.currentChargeStart + "% – " + TlpService.currentChargeStop + "%.")
                    }
                    return parts.join(" ")
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.WordWrap
            }

            StringSetting {
                settingKey: "batteryName"
                label: "Battery name"
                description: "Leave empty to use TLP's configured default. Auto-detected: " + (TlpService.detectedBattery || "—")
                placeholder: TlpService.detectedBattery || "BAT0"
                defaultValue: ""
            }

            SliderSetting {
                id: chargeStartSetting
                settingKey: "chargeStart"
                label: "Start charging at"
                defaultValue: 75
                minimum: 1
                maximum: 95
                unit: "%"
            }

            SliderSetting {
                id: chargeStopSetting
                settingKey: "chargeStop"
                label: "Stop charging at"
                defaultValue: 80
                minimum: 5
                maximum: 100
                unit: "%"
            }

            DankButton {
                text: "Apply thresholds"
                iconName: "battery_charging_full"
                onClicked: {
                    TlpService.applyChargeThresholds(
                        chargeStartSetting.value,
                        chargeStopSetting.value,
                        settings.loadValue("batteryName", ""),
                        settings.loadValue("privilegeMode", "pkexec")
                    )
                }
            }
        }
    }
}
