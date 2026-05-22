import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "tlpPowerProfile"

    readonly property var defaultProfiles: [
        { "id": "power_save",  "label": "Power Save",  "icon": "🍃", "command": "tlp bat" },
        { "id": "balanced",    "label": "Balanced",    "icon": "⚖️", "command": "tlp ac" },
        { "id": "performance", "label": "Performance", "icon": "⚡", "command": "tlp-power-profile-helper performance" }
    ]

    readonly property var profiles: {
        const p = pluginData ? pluginData.profiles : null
        return (Array.isArray(p) && p.length > 0) ? p : defaultProfiles
    }

    readonly property string activeProfileId: (pluginData && pluginData.activeProfileId) || "balanced"
    readonly property string privilegeMode: (pluginData && pluginData.privilegeMode) || "pkexec"
    readonly property int pollIntervalMs: (pluginData && pluginData.pollIntervalMs) || 5000

    readonly property var activeProfile: {
        const p = profiles.find(x => x.id === activeProfileId)
        return p || profiles[0]
    }

    Component.onCompleted: {
        TlpService.refresh()
    }

    function setProfile(profile) {
        if (!profile) return
        pluginService.savePluginData(pluginId, "activeProfileId", profile.id)
        TlpService.applyProfile(profile.command, privilegeMode, () => {
            postClickRefresh.restart()
        })
    }

    function cycleProfile() {
        const nextId = TlpService.nextProfileId(profiles, activeProfileId)
        const next = profiles.find(p => p.id === nextId)
        if (next) setProfile(next)
    }

    pillRightClickAction: function() {
        root.cycleProfile()
    }

    Timer {
        interval: root.pollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: TlpService.refresh()
    }

    Timer {
        id: postClickRefresh
        interval: 400
        repeat: false
        onTriggered: TlpService.refresh()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                name: BatteryService.batteryAvailable ? BatteryService.getBatteryIcon() : "bolt"
                color: BatteryService.isLowBattery && !BatteryService.isCharging ? Theme.error : Theme.surfaceText
                size: Theme.iconSize - 6
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: BatteryService.batteryAvailable ? BatteryService.batteryLevel + "%" : "—"
                color: BatteryService.isLowBattery && !BatteryService.isCharging ? Theme.error : Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.activeProfile ? root.activeProfile.icon : ""
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
                visible: text.length > 0
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: BatteryService.batteryAvailable ? BatteryService.getBatteryIcon() : "bolt"
                color: BatteryService.isLowBattery && !BatteryService.isCharging ? Theme.error : Theme.surfaceText
                size: Theme.iconSize - 6
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: BatteryService.batteryAvailable ? BatteryService.batteryLevel + "%" : "—"
                color: BatteryService.isLowBattery && !BatteryService.isCharging ? Theme.error : Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.activeProfile ? root.activeProfile.icon : ""
                font.pixelSize: Theme.fontSizeSmall
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text.length > 0
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            showCloseButton: false
            spacing: Theme.spacingM

            Row {
                width: parent.width - Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: 48
                spacing: Theme.spacingM

                DankIcon {
                    name: BatteryService.batteryAvailable ? BatteryService.getBatteryIcon() : "power"
                    size: Theme.iconSizeLarge
                    color: {
                        if (BatteryService.isLowBattery && !BatteryService.isCharging)
                            return Theme.error
                        if (BatteryService.isCharging || BatteryService.isPluggedIn)
                            return Theme.primary
                        return Theme.surfaceText
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.iconSizeLarge - 32 - Theme.spacingM * 2

                    Row {
                        spacing: Theme.spacingS

                        StyledText {
                            text: BatteryService.batteryAvailable ? BatteryService.batteryLevel + "%" : "Power"
                            font.pixelSize: Theme.fontSizeXLarge
                            font.weight: Font.Bold
                            color: {
                                if (BatteryService.isLowBattery && !BatteryService.isCharging)
                                    return Theme.error
                                if (BatteryService.isCharging)
                                    return Theme.primary
                                return Theme.surfaceText
                            }
                        }

                        StyledText {
                            text: BatteryService.batteryStatus
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            color: {
                                if (BatteryService.isLowBattery && !BatteryService.isCharging)
                                    return Theme.error
                                if (BatteryService.isCharging)
                                    return Theme.primary
                                return Theme.surfaceText
                            }
                            visible: BatteryService.batteryAvailable
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: {
                            if (!BatteryService.batteryAvailable)
                                return ""
                            const time = BatteryService.formatTimeRemaining()
                            if (time !== "Unknown") {
                                return BatteryService.isCharging ? "Time until full: " + time : "Time remaining: " + time
                            }
                            return ""
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceTextMedium
                        visible: text.length > 0
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: closeArea.containsMouse ? Theme.errorHover : "transparent"
                    anchors.top: parent.top

                    DankIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: Theme.iconSize - 4
                        color: closeArea.containsMouse ? Theme.error : Theme.surfaceText
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            if (popout.closePopout)
                                popout.closePopout()
                        }
                    }
                }
            }

            Row {
                width: parent.width - Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingM
                visible: BatteryService.batteryAvailable

                property real cardWidth: (width - spacing) / 2

                StyledRect {
                    width: parent.cardWidth
                    height: 64
                    radius: Theme.cornerRadius
                    color: Theme.nestedSurface
                    border.width: 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "Health"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.primary
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: BatteryService.batteryHealth
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            color: {
                                if (BatteryService.batteryHealth === "N/A")
                                    return Theme.surfaceText
                                const healthNum = parseInt(BatteryService.batteryHealth)
                                return healthNum < 80 ? Theme.error : Theme.surfaceText
                            }
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                StyledRect {
                    width: parent.cardWidth
                    height: 64
                    radius: Theme.cornerRadius
                    color: Theme.nestedSurface
                    border.width: 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "Capacity"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.primary
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: BatteryService.batteryAvailable
                                ? BatteryService.batteryEnergy.toFixed(1) + " Wh"
                                : "—"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            Item {
                width: parent.width - Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: profileButtonGroup.height * profileButtonGroup.scale

                DankButtonGroup {
                    id: profileButtonGroup
                    scale: Math.min(1, parent.width / implicitWidth)
                    transformOrigin: Item.Center
                    anchors.horizontalCenter: parent.horizontalCenter
                    model: root.profiles.map(p => p.label)
                    currentIndex: root.profiles.findIndex(p => p.id === root.activeProfileId)
                    selectionMode: "single"
                    onSelectionChanged: (index, selected) => {
                        if (!selected) return
                        const profile = root.profiles[index]
                        if (profile) root.setProfile(profile)
                    }
                }
            }

            Item {
                width: parent.width - Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: modeLabel.implicitHeight
                visible: TlpService.currentMode.length > 0

                StyledText {
                    id: modeLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "TLP mode: " + TlpService.currentMode
                    font.pixelSize: Theme.fontSizeSmall
                    color: TlpService.privilegedCallsFailing ? Theme.error : Theme.surfaceTextMedium
                }
            }

            Item {
                width: 1
                height: Theme.spacingL
            }
        }
    }

    popoutWidth: 420
    popoutHeight: 320
}
