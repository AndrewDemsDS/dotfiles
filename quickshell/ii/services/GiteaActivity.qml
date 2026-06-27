pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Gitea activity service. Polls a user's activity feed and exposes a short list of
 * recent actions (commits pushed, issues/PRs opened, …) for a sidebar card.
 *   GET /api/v1/users/<user>/activities/feeds?limit=15
 *       Authorization: token <tok>
 * The token is read from an UNTRACKED file (quickshell/secrets/gitea_token); base URL
 * and user come from Config. Nothing personal is hardcoded in-repo.
 */
Singleton {
    id: root

    readonly property string secretsPath: `${FileUtils.trimFileProtocol(Directories.config)}/quickshell/secrets/gitea_token`
    property string token: ""

    function _strip(u) {
        return u.endsWith("/") ? u.slice(0, -1) : u;
    }
    readonly property string baseUrl: _strip(Config.options.giteaActivity.baseUrl)
    readonly property string user: Config.options.giteaActivity.user
    readonly property bool configured: root.baseUrl.length > 0 && root.user.length > 0 && root.token.length > 0

    property var feed: [] // [{repo, act, created, summary}]
    property int count: 0
    property bool online: false
    property bool loading: false
    property bool unauthorized: false

    // Relative-time helper for the widget (e.g. "3h", "2d").
    function relativeTime(iso) {
        if (!iso || iso.length === 0)
            return "";
        const then = Date.parse(iso);
        if (isNaN(then))
            return "";
        const secs = Math.max(0, (Date.now() - then) / 1000);
        if (secs < 60)
            return Translation.tr("now");
        const mins = Math.floor(secs / 60);
        if (mins < 60)
            return `${mins}m`;
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return `${hours}h`;
        const days = Math.floor(hours / 24);
        if (days < 7)
            return `${days}d`;
        return `${Math.floor(days / 7)}w`;
    }

    // Human label for a Gitea op_type enum value.
    function _actLabel(op) {
        switch (op) {
        case "commit_repo":
            return Translation.tr("pushed to");
        case "create_repo":
            return Translation.tr("created");
        case "create_issue":
            return Translation.tr("opened issue in");
        case "create_pull_request":
            return Translation.tr("opened PR in");
        case "comment_issue":
            return Translation.tr("commented in");
        case "merge_pull_request":
            return Translation.tr("merged PR in");
        case "close_issue":
            return Translation.tr("closed issue in");
        case "reopen_issue":
            return Translation.tr("reopened issue in");
        case "delete_branch":
            return Translation.tr("deleted branch in");
        case "push_tag":
            return Translation.tr("tagged");
        case "create_branch":
            return Translation.tr("branched");
        case "star_repo":
            return Translation.tr("starred");
        case "transfer_repo":
            return Translation.tr("transferred");
        default:
            return (op ?? "").replace(/_/g, " ");
        }
    }

    function refresh() {
        if (!Config.options.giteaActivity.enable)
            return;
        if (root.token.length === 0) {
            tokenProc.running = true;
            return;
        }
        if (root.baseUrl.length === 0 || root.user.length === 0)
            return;
        root.loading = true;
        const limit = Math.max(1, Math.min(50, Config.options.giteaActivity.limit));
        const xhr = new XMLHttpRequest();
        xhr.open("GET", `${root.baseUrl}/api/v1/users/${encodeURIComponent(root.user)}/activities/feeds?limit=${limit}`);
        xhr.setRequestHeader("Authorization", `token ${root.token}`);
        xhr.setRequestHeader("Accept", "application/json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            root.loading = false;
            if (xhr.status === 401 || xhr.status === 403) {
                root.unauthorized = true;
                root.online = false;
                return;
            }
            if (xhr.status !== 200) {
                root.online = false;
                return;
            }
            root.unauthorized = false;
            try {
                const arr = JSON.parse(xhr.responseText);
                let out = [];
                for (const a of (Array.isArray(arr) ? arr : [])) {
                    const repo = a.repo?.full_name ?? a.repo?.name ?? "";
                    out.push({
                        "repo": repo,
                        "act": root._actLabel(a.op_type),
                        "created": a.created ?? "",
                        "summary": (a.content ?? "").split("\n")[0]
                    });
                }
                root.feed = out;
                root.count = out.length;
                root.online = true;
            } catch (e) {
                console.log("[GiteaActivity] parse failed:", e);
                root.online = false;
            }
        };
        xhr.onerror = function () {
            root.loading = false;
            root.online = false;
        };
        xhr.send();
    }

    Process {
        id: tokenProc
        command: ["cat", root.secretsPath]
        stdout: StdioCollector {
            onStreamFinished: {
                root.token = text.trim();
                if (root.token.length > 0)
                    root.refresh();
            }
        }
    }

    Timer {
        interval: Math.max(1, Config.options.giteaActivity.pollMinutes) * 60000
        repeat: true
        running: Config.ready && Config.options.giteaActivity.enable
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "giteaActivity"
        function refresh(): void {
            root.refresh();
        }
        function status(): string {
            return `configured=${root.configured} online=${root.online} unauthorized=${root.unauthorized} items=${root.count}`;
        }
    }
}
