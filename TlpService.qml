pragma Singleton

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    id: root

    property string currentMode: ""
    property string detectedBattery: ""
    property int currentChargeStart: -1
    property int currentChargeStop: -1
    property bool privilegedCallsFailing: false
    property string lastError: ""

    signal stateRefreshed

    function refresh() {
        Proc.runCommand("tlpService.statS", ["tlp-stat", "-s"], (stdout, exitCode) => {
            if (exitCode !== 0) {
                root.lastError = "tlp-stat -s exited " + exitCode
                return
            }
            const m = stdout.match(/Power source\s*=\s*(\S+)/i)
            if (m) {
                root.currentMode = m[1].toUpperCase()
            }
            root.stateRefreshed()
        }, 50, 5000)

        Proc.runCommand("tlpService.statB", ["tlp-stat", "-b"], (stdout, exitCode) => {
            if (exitCode !== 0) {
                return
            }
            root._parseBattery(stdout)
        }, 50, 5000)
    }

    function _parseBattery(text) {
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            const nameMatch = line.match(/^\+\+\+ Battery Status:\s*(\S+)/)
            if (nameMatch && !root.detectedBattery) {
                root.detectedBattery = nameMatch[1]
            }
            const startMatch = line.match(/charge_control_start_threshold.*?=\s*(\d+)/)
            if (startMatch) {
                root.currentChargeStart = parseInt(startMatch[1])
                continue
            }
            const stopMatch = line.match(/charge_control_end_threshold.*?=\s*(\d+)/)
            if (stopMatch) {
                root.currentChargeStop = parseInt(stopMatch[1])
                continue
            }
            const startTlp = line.match(/^START_CHARGE_THRESH_\w+\s*=\s*(\d+)/)
            if (startTlp && root.currentChargeStart < 0) {
                root.currentChargeStart = parseInt(startTlp[1])
                continue
            }
            const stopTlp = line.match(/^STOP_CHARGE_THRESH_\w+\s*=\s*(\d+)/)
            if (stopTlp && root.currentChargeStop < 0) {
                root.currentChargeStop = parseInt(stopTlp[1])
                continue
            }
        }
    }

    function _privPrefix(privilegeMode) {
        if (privilegeMode === "sudo") return ["sudo", "-n"]
        if (privilegeMode === "none") return []
        return ["pkexec"]
    }

    function applyProfile(commandString, privilegeMode, onDone) {
        if (!commandString) {
            ToastService.showError("TLP Power Profile: empty command for profile")
            return
        }
        const parts = commandString.trim().split(/\s+/).filter(p => p.length > 0)
        const argv = _privPrefix(privilegeMode).concat(parts)
        Proc.runCommand("tlpService.apply", argv, (stdout, exitCode) => {
            if (exitCode !== 0) {
                root.privilegedCallsFailing = true
                root.lastError = "exit " + exitCode + ": " + stdout
                ToastService.showError("TLP call failed — check privilege setup",
                                       argv.join(" ") + "\n" + stdout)
            } else {
                root.privilegedCallsFailing = false
            }
            if (onDone) onDone(exitCode)
        }, 50, 10000)
    }

    function applyChargeThresholds(start, stop, battery, privilegeMode, onDone) {
        if (stop <= start + 3) {
            ToastService.showError("Charge thresholds invalid",
                                   "Stop (" + stop + ") must be at least 4 greater than start (" + start + ").")
            if (onDone) onDone(2)
            return
        }
        if (start < 1 || stop > 100) {
            ToastService.showError("Charge thresholds out of range",
                                   "Both must be between 1 and 100.")
            if (onDone) onDone(2)
            return
        }
        let argv = _privPrefix(privilegeMode).concat(["tlp", "setcharge", String(start), String(stop)])
        if (battery && battery.length > 0) {
            argv.push(battery)
        }
        Proc.runCommand("tlpService.setcharge", argv, (stdout, exitCode) => {
            if (exitCode !== 0) {
                root.privilegedCallsFailing = true
                ToastService.showError("tlp setcharge failed", stdout)
            } else {
                root.privilegedCallsFailing = false
                root.currentChargeStart = start
                root.currentChargeStop = stop
                ToastService.showInfo("Charge thresholds applied",
                                      start + "% – " + stop + "%" + (battery ? " (" + battery + ")" : ""))
            }
            if (onDone) onDone(exitCode)
        }, 50, 10000)
    }

    function nextProfileId(profiles, currentId) {
        if (!profiles || profiles.length === 0) return ""
        const idx = profiles.findIndex(p => p.id === currentId)
        const next = (idx + 1) % profiles.length
        return profiles[next].id
    }
}
