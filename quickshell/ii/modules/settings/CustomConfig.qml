import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Settings for the custom (non-upstream) features. Each section starts with an enable
// switch; disabling fully stops the feature (service + widget + keybind). Secrets (HA
// token, SSH key contents) stay in quickshell/secrets/ — only non-secret fields are here.
ContentPage {
    forceWidth: true

    // ── Home Assistant ──────────────────────────────────────────────
    ContentSection {
        icon: "home"
        title: Translation.tr("Home Assistant")

        ConfigSwitch {
            text: Translation.tr("Enable Home Assistant control")
            checked: Config.options.homeAssistant.enable
            onCheckedChanged: Config.options.homeAssistant.enable = checked
            StyledToolTip { text: Translation.tr("Needs baseUrl + a token at quickshell/secrets/ha_token") }
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Base URL (e.g. https://home.example.com)")
            text: Config.options.homeAssistant.baseUrl
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.homeAssistant.baseUrl = text
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Fallback URL (optional standby)")
            text: Config.options.homeAssistant.fallbackUrl
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.homeAssistant.fallbackUrl = text
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Dashboard path opened by Super+Alt+H (e.g. lovelace)")
            text: Config.options.homeAssistant.dashboardPath
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.homeAssistant.dashboardPath = text
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Poll interval (s)")
            value: Config.options.homeAssistant.pollSeconds
            from: 1; to: 60; stepSize: 1
            onValueChanged: Config.options.homeAssistant.pollSeconds = value
        }
        ContentSubsection {
            title: Translation.tr("Entities (one entity_id per line)")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("light.kitchen\nclimate.bedroom\nscene.movie")
                wrapMode: TextEdit.Wrap
                Component.onCompleted: text = (Config.options.homeAssistant.entities ?? []).join("\n")
                onTextChanged: Config.options.homeAssistant.entities = text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
            }
        }
    }

    // ── UPS / battery HUD ───────────────────────────────────────────
    ContentSection {
        icon: "battery_charging_full"
        title: Translation.tr("UPS / battery HUD")

        ConfigSwitch {
            text: Translation.tr("Enable UPS HUD")
            checked: Config.options.upsMonitor.enable
            onCheckedChanged: Config.options.upsMonitor.enable = checked
            StyledToolTip { text: Translation.tr("Sources the battery from Home Assistant sensors") }
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Battery % entity (e.g. sensor.battery_soc)")
            text: Config.options.upsMonitor.batteryEntity
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.upsMonitor.batteryEntity = text
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Charging entity (binary_sensor…)")
            text: Config.options.upsMonitor.chargingEntity
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.upsMonitor.chargingEntity = text
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Current (A) entity")
            text: Config.options.upsMonitor.currentEntity
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.upsMonitor.currentEntity = text
        }
        ContentSubsection {
            title: Translation.tr("On-battery current threshold (A)")
            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: "0.5"
                Component.onCompleted: text = String(Config.options.upsMonitor.dischargeAmps)
                onTextChanged: {
                    const v = parseFloat(text);
                    if (!isNaN(v)) Config.options.upsMonitor.dischargeAmps = v;
                }
            }
        }
    }

    // ── NAS / media guard ───────────────────────────────────────────
    ContentSection {
        icon: "dns"
        title: Translation.tr("NAS / media guard")

        ConfigSwitch {
            text: Translation.tr("Enable NAS guard")
            checked: Config.options.nasGuard.enable
            onCheckedChanged: Config.options.nasGuard.enable = checked
        }
        ConfigSwitch {
            text: Translation.tr("Show container health")
            checked: Config.options.nasGuard.showContainers
            onCheckedChanged: Config.options.nasGuard.showContainers = checked
        }
        ConfigRow {
            uniform: true
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("SSH host")
                text: Config.options.nasGuard.sshHost
                wrapMode: TextEdit.Wrap
                onTextChanged: Config.options.nasGuard.sshHost = text
            }
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("SSH user")
                text: Config.options.nasGuard.sshUser
                wrapMode: TextEdit.Wrap
                onTextChanged: Config.options.nasGuard.sshUser = text
            }
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("SSH private-key path")
            text: Config.options.nasGuard.sshKey
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.nasGuard.sshKey = text
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Mount to check free space (e.g. /mnt/storage)")
            text: Config.options.nasGuard.dfMount
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.nasGuard.dfMount = text
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Alt: HA sensor reporting GiB free (optional)")
            text: Config.options.nasGuard.freeSpaceEntity
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.nasGuard.freeSpaceEntity = text
        }
        ConfigSpinBox {
            icon: "lan"
            text: Translation.tr("SSH port")
            value: Config.options.nasGuard.sshPort
            from: 1; to: 65535; stepSize: 1
            onValueChanged: Config.options.nasGuard.sshPort = value
        }
        ConfigSpinBox {
            icon: "warning"
            text: Translation.tr("Warn below (GiB free)")
            value: Config.options.nasGuard.guardGiB
            from: 1; to: 1000; stepSize: 1
            onValueChanged: Config.options.nasGuard.guardGiB = value
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Poll interval (s)")
            value: Config.options.nasGuard.pollSeconds
            from: 15; to: 600; stepSize: 5
            onValueChanged: Config.options.nasGuard.pollSeconds = value
        }
    }

    // ── VPN / network pill ──────────────────────────────────────────
    ContentSection {
        icon: "vpn_key"
        title: Translation.tr("VPN / network pill")

        ConfigSwitch {
            text: Translation.tr("Enable VPN pill")
            checked: Config.options.vpnStatus.enable
            onCheckedChanged: Config.options.vpnStatus.enable = checked
        }
        ConfigSwitch {
            text: Translation.tr("Public-IP geo lookup on network change")
            checked: Config.options.vpnStatus.geoLookup
            onCheckedChanged: Config.options.vpnStatus.geoLookup = checked
        }
        ConfigSwitch {
            text: Translation.tr("Auto-connect VPN off home networks")
            checked: Config.options.vpnStatus.autoConnect
            onCheckedChanged: Config.options.vpnStatus.autoConnect = checked
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Poll interval (s)")
            value: Config.options.vpnStatus.pollSeconds
            from: 5; to: 120; stepSize: 5
            onValueChanged: Config.options.vpnStatus.pollSeconds = value
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Default toggle connection (NM name; empty = auto)")
            text: Config.options.vpnStatus.toggleConnection
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.vpnStatus.toggleConnection = text
        }
        ContentSubsection {
            title: Translation.tr("Trusted SSIDs (one per line)")
            MaterialTextArea {
                Layout.fillWidth: true
                wrapMode: TextEdit.Wrap
                Component.onCompleted: text = (Config.options.vpnStatus.trustedSsids ?? []).join("\n")
                onTextChanged: Config.options.vpnStatus.trustedSsids = text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
            }
        }
        ContentSubsection {
            title: Translation.tr("Trusted subnets (IP prefixes, one per line)")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: "192.168.1"
                wrapMode: TextEdit.Wrap
                Component.onCompleted: text = (Config.options.vpnStatus.trustedSubnets ?? []).join("\n")
                onTextChanged: Config.options.vpnStatus.trustedSubnets = text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
            }
        }
    }

    // ── News / RSS ──────────────────────────────────────────────────
    ContentSection {
        icon: "rss_feed"
        title: Translation.tr("News / RSS")

        ConfigSwitch {
            text: Translation.tr("Enable News tab")
            checked: Config.options.sidebar.news.enable
            onCheckedChanged: Config.options.sidebar.news.enable = checked
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Poll interval (min)")
            value: Config.options.sidebar.news.pollMinutes
            from: 1; to: 180; stepSize: 1
            onValueChanged: Config.options.sidebar.news.pollMinutes = value
        }
        ConfigSpinBox {
            icon: "format_list_numbered"
            text: Translation.tr("Max items")
            value: Config.options.sidebar.news.maxItems
            from: 5; to: 100; stepSize: 5
            onValueChanged: Config.options.sidebar.news.maxItems = value
        }
        ContentSubsection {
            title: Translation.tr("Feeds (one per line: Name | https://url)")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("The Hacker News | https://feeds.feedburner.com/TheHackersNews")
                wrapMode: TextEdit.Wrap
                Component.onCompleted: text = (Config.options.sidebar.news.feeds ?? []).map(f => `${f.name ?? ""} | ${f.url ?? ""}`).join("\n")
                onTextChanged: {
                    const out = [];
                    for (const line of text.split("\n")) {
                        const t = line.trim();
                        if (t.length === 0) continue;
                        const i = t.indexOf("|");
                        if (i < 0) { out.push({ "name": t, "url": t }); continue; }
                        out.push({ "name": t.slice(0, i).trim(), "url": t.slice(i + 1).trim() });
                    }
                    Config.options.sidebar.news.feeds = out;
                }
            }
        }
    }

    // ── Local LLM text actions ──────────────────────────────────────
    ContentSection {
        icon: "smart_toy"
        title: Translation.tr("Local LLM (text actions)")

        ConfigSwitch {
            text: Translation.tr("Enable LLM text actions (Super+Alt+I)")
            checked: Config.options.localLlm.enable
            onCheckedChanged: Config.options.localLlm.enable = checked
            StyledToolTip { text: Translation.tr("Runs against a LOCAL Ollama only") }
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Ollama base URL (http://localhost:11434)")
            text: Config.options.localLlm.baseUrl
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.localLlm.baseUrl = text
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Model (empty = first installed)")
            text: Config.options.localLlm.model
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.localLlm.model = text
        }
    }

    // ── Dotfiles drift ──────────────────────────────────────────────
    ContentSection {
        icon: "difference"
        title: Translation.tr("Dotfiles drift")

        ConfigSwitch {
            text: Translation.tr("Enable drift notifier")
            checked: Config.options.dotfilesDrift.enable
            onCheckedChanged: Config.options.dotfilesDrift.enable = checked
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Repo path (empty = ~/.config)")
            text: Config.options.dotfilesDrift.repoPath
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.dotfilesDrift.repoPath = text
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Check interval (min)")
            value: Config.options.dotfilesDrift.checkInterval
            from: 1; to: 120; stepSize: 1
            onValueChanged: Config.options.dotfilesDrift.checkInterval = value
        }
        ConfigSpinBox {
            icon: "notifications_active"
            text: Translation.tr("Nag after (hours)")
            value: Config.options.dotfilesDrift.nagAfterHours
            from: 1; to: 48; stepSize: 1
            onValueChanged: Config.options.dotfilesDrift.nagAfterHours = value
        }
    }

    // ── Data usage / bandwidth pill ─────────────────────────────────
    ContentSection {
        icon: "speed"
        title: Translation.tr("Data usage / bandwidth pill")

        ConfigSwitch {
            text: Translation.tr("Enable data-usage pill")
            checked: Config.options.netUsage.enable
            onCheckedChanged: Config.options.netUsage.enable = checked
            StyledToolTip { text: Translation.tr("Live down/up speed + monthly total from /proc/net/dev") }
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Interface: \"auto\", or a name like wlan0 / eth0 / usb0")
            text: Config.options.netUsage.iface
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.netUsage.iface = text
            StyledToolTip {
                text: Translation.tr("\"auto\" follows the default-route interface (Wi-Fi, Ethernet, USB tethering, …). Currently metering: %1").arg(NetUsage.activeIface || Translation.tr("none"))
            }
        }
        ConfigSpinBox {
            icon: "data_usage"
            text: Translation.tr("Monthly cap (GiB, 0 = none)")
            value: Config.options.netUsage.monthlyCapGiB
            from: 0; to: 100000; stepSize: 1
            onValueChanged: Config.options.netUsage.monthlyCapGiB = value
        }
        ConfigSpinBox {
            icon: "warning"
            text: Translation.tr("Warn at (% of cap)")
            value: Config.options.netUsage.warnPercent
            from: 1; to: 100; stepSize: 5
            onValueChanged: Config.options.netUsage.warnPercent = value
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Poll interval (s)")
            value: Config.options.netUsage.pollSeconds
            from: 1; to: 60; stepSize: 1
            onValueChanged: Config.options.netUsage.pollSeconds = value
        }
    }

    // ── Next-class / timetable ──────────────────────────────────────
    ContentSection {
        icon: "school"
        title: Translation.tr("Next-class / timetable")

        ConfigSwitch {
            text: Translation.tr("Enable timetable pill")
            checked: Config.options.timetable.enable
            onCheckedChanged: Config.options.timetable.enable = checked
            StyledToolTip { text: Translation.tr("Shows the next upcoming class + a countdown in the bar") }
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Schedule file path (.json or .ics, e.g. ~/schedule.json)")
            text: Config.options.timetable.schedulePath
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.timetable.schedulePath = text
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Poll interval (s)")
            value: Config.options.timetable.pollSeconds
            from: 15; to: 600; stepSize: 5
            onValueChanged: Config.options.timetable.pollSeconds = value
        }
    }

    // ── Deadlines + focus DND ───────────────────────────────────────
    ContentSection {
        icon: "event"
        title: Translation.tr("Deadlines")

        ConfigSwitch {
            text: Translation.tr("Enable deadline tracker")
            checked: Config.options.deadlines.enable
            onCheckedChanged: Config.options.deadlines.enable = checked
        }
        ConfigSwitch {
            text: Translation.tr("Do-Not-Disturb during Pomodoro focus")
            checked: Config.options.deadlines.dndOnFocus
            onCheckedChanged: Config.options.deadlines.dndOnFocus = checked
            StyledToolTip { text: Translation.tr("Silences notification popups while a focus lap runs") }
        }
        ConfigSpinBox {
            icon: "warning"
            text: Translation.tr("Flag as soon when within (days)")
            value: Config.options.deadlines.soonDays
            from: 0; to: 60; stepSize: 1
            onValueChanged: Config.options.deadlines.soonDays = value
        }
        ContentSubsection {
            title: Translation.tr("Deadlines (one per line: Name | YYYY-MM-DD)")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Thesis preference form | 2026-05-25")
                wrapMode: TextEdit.Wrap
                Component.onCompleted: text = (Config.options.deadlines.items ?? []).map(d => `${d.name ?? ""} | ${d.due ?? ""}`).join("\n")
                onTextChanged: {
                    const out = [];
                    for (const line of text.split("\n")) {
                        const t = line.trim();
                        if (t.length === 0) continue;
                        const i = t.indexOf("|");
                        if (i < 0) continue;
                        out.push({ "name": t.slice(0, i).trim(), "due": t.slice(i + 1).trim() });
                    }
                    Config.options.deadlines.items = out;
                }
            }
        }
    }

    // ── Service quick-launcher ──────────────────────────────────────
    ContentSection {
        icon: "apps"
        title: Translation.tr("Service launcher")

        ConfigSwitch {
            text: Translation.tr("Enable service launcher (Super+Alt+L)")
            checked: Config.options.serviceLauncher.enable
            onCheckedChanged: Config.options.serviceLauncher.enable = checked
            StyledToolTip { text: Translation.tr("Opens each service in a Brave app-window") }
        }
        ContentSubsection {
            title: Translation.tr("Services (one per line: Name | https://url | icon)")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Jellyfin | https://jellyfin.example.com | movie")
                wrapMode: TextEdit.Wrap
                Component.onCompleted: text = (Config.options.serviceLauncher.services ?? []).map(s => `${s.name ?? ""} | ${s.url ?? ""} | ${s.icon ?? ""}`).join("\n")
                onTextChanged: {
                    const out = [];
                    for (const line of text.split("\n")) {
                        const t = line.trim();
                        if (t.length === 0) continue;
                        const parts = t.split("|").map(p => p.trim());
                        out.push({ "name": parts[0] ?? "", "url": parts[1] ?? parts[0] ?? "", "icon": parts[2] ?? "lan" });
                    }
                    Config.options.serviceLauncher.services = out;
                }
            }
        }
    }

    // ── Service health board ────────────────────────────────────────
    ContentSection {
        icon: "monitor_heart"
        title: Translation.tr("Service health board")

        ConfigSwitch {
            text: Translation.tr("Enable service health board")
            checked: Config.options.serviceHealth.enable
            onCheckedChanged: Config.options.serviceHealth.enable = checked
            StyledToolTip { text: Translation.tr("Probes each service with an XHR GET; green = reachable, red = down") }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Poll interval (s)")
            value: Config.options.serviceHealth.pollSeconds
            from: 10; to: 600; stepSize: 5
            onValueChanged: Config.options.serviceHealth.pollSeconds = value
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Uptime-Kuma URL (optional)")
            text: Config.options.serviceHealth.kumaUrl
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.serviceHealth.kumaUrl = text
        }
        ContentSubsection {
            title: Translation.tr("Services (one per line: Name | https://url)")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Jellyfin | https://jellyfin.example.com")
                wrapMode: TextEdit.Wrap
                Component.onCompleted: text = (Config.options.serviceHealth.services ?? []).map(s => `${s.name ?? ""} | ${s.url ?? ""}`).join("\n")
                onTextChanged: {
                    const out = [];
                    for (const line of text.split("\n")) {
                        const t = line.trim();
                        if (t.length === 0) continue;
                        const i = t.indexOf("|");
                        if (i < 0) { out.push({ "name": t, "url": t }); continue; }
                        out.push({ "name": t.slice(0, i).trim(), "url": t.slice(i + 1).trim() });
                    }
                    Config.options.serviceHealth.services = out;
                }
            }
        }
    }

    // ── Gitea activity ──────────────────────────────────────────────
    ContentSection {
        icon: "forum"
        title: Translation.tr("Gitea activity")

        ConfigSwitch {
            text: Translation.tr("Enable Gitea activity card")
            checked: Config.options.giteaActivity.enable
            onCheckedChanged: Config.options.giteaActivity.enable = checked
            StyledToolTip { text: Translation.tr("Needs baseUrl + user + a token at quickshell/secrets/gitea_token") }
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Base URL (e.g. https://git.example.com)")
            text: Config.options.giteaActivity.baseUrl
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.giteaActivity.baseUrl = text
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Gitea username")
            text: Config.options.giteaActivity.user
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.giteaActivity.user = text
        }
        ConfigSpinBox {
            icon: "format_list_numbered"
            text: Translation.tr("Feed items")
            value: Config.options.giteaActivity.limit
            from: 1; to: 50; stepSize: 1
            onValueChanged: Config.options.giteaActivity.limit = value
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Poll interval (min)")
            value: Config.options.giteaActivity.pollMinutes
            from: 1; to: 180; stepSize: 1
            onValueChanged: Config.options.giteaActivity.pollMinutes = value
        }
    }

    // ── Homelab glance ──────────────────────────────────────────────
    ContentSection {
        icon: "dns"
        title: Translation.tr("Homelab glance")

        ConfigSwitch {
            text: Translation.tr("Enable glance overlay (Super+Alt+G)")
            checked: Config.options.homelabGlance.enable
            onCheckedChanged: Config.options.homelabGlance.enable = checked
            StyledToolTip { text: Translation.tr("A summary card sourced from the UPS / NAS / News / Weather features already configured above") }
        }
    }

    // ── Sensor sparkline ────────────────────────────────────────────
    ContentSection {
        icon: "monitoring"
        title: Translation.tr("Sensor sparkline")

        ConfigSwitch {
            text: Translation.tr("Enable sensor sparkline card")
            checked: Config.options.sensorSparkline.enable
            onCheckedChanged: Config.options.sensorSparkline.enable = checked
            StyledToolTip { text: Translation.tr("Live mini-graphs from Home Assistant sensors (reuses the HA token)") }
        }
        ConfigSpinBox {
            icon: "show_chart"
            text: Translation.tr("Samples (graph width)")
            value: Config.options.sensorSparkline.samples
            from: 2; to: 300; stepSize: 10
            onValueChanged: Config.options.sensorSparkline.samples = value
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Poll interval (s)")
            value: Config.options.sensorSparkline.pollSeconds
            from: 2; to: 120; stepSize: 1
            onValueChanged: Config.options.sensorSparkline.pollSeconds = value
        }
        ContentSubsection {
            title: Translation.tr("Sensors (one per line: Name | sensor.entity_id | unit)")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Power | sensor.eac_real_time_power_import | W")
                wrapMode: TextEdit.Wrap
                Component.onCompleted: text = (Config.options.sensorSparkline.entities ?? []).map(e => `${e.name ?? ""} | ${e.entity ?? ""} | ${e.unit ?? ""}`).join("\n")
                onTextChanged: {
                    const out = [];
                    for (const line of text.split("\n")) {
                        const t = line.trim();
                        if (t.length === 0) continue;
                        const parts = t.split("|").map(s => s.trim());
                        const entity = parts[1] ?? parts[0];
                        out.push({ "name": parts[0] ?? "", "entity": entity, "unit": parts[2] ?? "" });
                    }
                    Config.options.sensorSparkline.entities = out;
                }
            }
        }
    }

    // ── Recon launcher ──────────────────────────────────────────────
    ContentSection {
        icon: "security"
        title: Translation.tr("Recon launcher")

        ConfigSwitch {
            text: Translation.tr("Enable recon launcher (Super+Alt+P)")
            checked: Config.options.reconLauncher.enable
            onCheckedChanged: Config.options.reconLauncher.enable = checked
            StyledToolTip { text: Translation.tr("Runs read-only recon tools against allowlisted hosts you OWN") }
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Terminal (e.g. foot / kitty; empty = xdg-terminal-exec)")
            text: Config.options.reconLauncher.terminal
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.reconLauncher.terminal = text
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("ffuf wordlist path (optional; ffuf disabled until set)")
            text: Config.options.reconLauncher.wordlist
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.reconLauncher.wordlist = text
        }
        ContentSubsection {
            title: Translation.tr("Allowlist — host/IP prefixes you OWN (one per line)")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("example.com\n10.0.0\nlocalhost")
                wrapMode: TextEdit.Wrap
                Component.onCompleted: text = (Config.options.reconLauncher.allowlist ?? []).join("\n")
                onTextChanged: Config.options.reconLauncher.allowlist = text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
            }
        }
    }

    // ── Printer ─────────────────────────────────────────────────────
    ContentSection {
        icon: "print"
        title: Translation.tr("Printer")

        ConfigSwitch {
            text: Translation.tr("Enable printer integration")
            checked: Config.options.printer.enable
            onCheckedChanged: Config.options.printer.enable = checked
            StyledToolTip { text: Translation.tr("Polls CUPS (lpstat) for printers + the job queue") }
        }
        ConfigSwitch {
            text: Translation.tr("Always show pill (even when idle)")
            checked: Config.options.printer.showWhenIdle
            onCheckedChanged: Config.options.printer.showWhenIdle = checked
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Poll interval (s)")
            value: Config.options.printer.pollSeconds
            from: 5; to: 300; stepSize: 5
            onValueChanged: Config.options.printer.pollSeconds = value
        }
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Queue command (empty = CUPS web UI at localhost:631)")
            text: Config.options.printer.queueCommand
            wrapMode: TextEdit.Wrap
            onTextChanged: Config.options.printer.queueCommand = text
        }
    }
}
