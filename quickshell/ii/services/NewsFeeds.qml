pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * RSS/Atom news aggregator. Fetches each configured feed via XHR, parses with the QML
 * responseXML DOM, merges + sorts by date, and tracks read/unread (persisted to disk).
 * Feeds come from Config.options.sidebar.news.feeds [{name, url}].
 */
Singleton {
    id: root

    property var items: [] // [{title, link, date(ms), dateStr, summary, source}]
    property var readLinks: ({}) // link -> true
    property int pending: 0
    property bool loading: false

    // Reader: extracted article shown in the centered reader window
    property string articleUrl: ""
    property var article: null
    property bool articleLoading: false

    function openArticle(url) {
        if (!url || url.length === 0)
            return;
        root.articleUrl = url;
        root.article = null;
        root.articleLoading = true;
        readerProc.command = ["bash", `${Directories.scriptPath}/news/read-article.sh`, url];
        readerProc.running = true;
        root.markRead(url);
    }
    function closeArticle() {
        root.articleUrl = "";
        root.article = null;
        root.articleLoading = false;
    }

    readonly property int unreadCount: {
        let n = 0;
        for (const it of root.items)
            if (!root.readLinks[it.link])
                n++;
        return n;
    }

    function isRead(link) {
        return root.readLinks[link] === true;
    }
    function _persistRead(m) {
        root.readLinks = m; // new object => bindings (unread count, dots) update
        readFileView.setText(JSON.stringify(Object.keys(m)));
    }
    function markRead(link) {
        if (!link || root.readLinks[link])
            return;
        let m = Object.assign({}, root.readLinks);
        m[link] = true;
        root._persistRead(m);
    }
    function markUnread(link) {
        if (!link || !root.readLinks[link])
            return;
        let m = Object.assign({}, root.readLinks);
        delete m[link];
        root._persistRead(m);
    }
    function toggleRead(link) {
        if (root.isRead(link))
            root.markUnread(link);
        else
            root.markRead(link);
    }
    function markAllRead() {
        let m = Object.assign({}, root.readLinks);
        for (const it of root.items)
            m[it.link] = true;
        root._persistRead(m);
    }

    function refresh() {
        if (!Config.options.sidebar.news.enable)
            return;
        const feeds = Config.options.sidebar.news.feeds;
        if (!feeds || feeds.length === 0)
            return;
        root.loading = true;
        root.pending = feeds.length;
        let acc = [];
        for (const feed of feeds)
            root._fetch(feed, acc);
    }

    function _fetch(feed, acc) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", feed.url);
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            try {
                if (xhr.status === 200 && xhr.responseXML)
                    root._parse(xhr.responseXML, feed.name || feed.url, acc);
            } catch (e) {
                console.log("[News] parse failed:", feed.url, e);
            }
            root.pending--;
            if (root.pending <= 0) {
                acc.sort((a, b) => b.date - a.date);
                root.items = acc.slice(0, Config.options.sidebar.news.maxItems);
                root.loading = false;
            }
        };
        xhr.send();
    }

    function _text(node, tag) {
        for (let i = 0; i < node.childNodes.length; i++) {
            const c = node.childNodes[i];
            if (c.nodeName && c.nodeName.toLowerCase() === tag) {
                let t = "";
                for (let j = 0; j < c.childNodes.length; j++)
                    if (c.childNodes[j].nodeValue)
                        t += c.childNodes[j].nodeValue;
                return t.trim();
            }
        }
        return "";
    }

    function _linkOf(node) {
        for (let i = 0; i < node.childNodes.length; i++) {
            const c = node.childNodes[i];
            if (!c.nodeName || c.nodeName.toLowerCase() !== "link")
                continue;
            let t = "";
            for (let j = 0; j < c.childNodes.length; j++)
                if (c.childNodes[j].nodeValue)
                    t += c.childNodes[j].nodeValue;
            if (t.trim().length > 0)
                return t.trim();
            // Atom: <link href="..."/>
            try {
                if (c.attributes) {
                    for (let k = 0; k < c.attributes.length; k++) {
                        const a = c.attributes[k];
                        if (a.nodeName && a.nodeName.toLowerCase() === "href")
                            return a.nodeValue;
                    }
                }
            } catch (e) {}
        }
        return "";
    }

    function _parse(doc, source, acc) {
        let nodes = [];
        function walk(n) {
            if (!n)
                return;
            const nm = n.nodeName ? n.nodeName.toLowerCase() : "";
            if (nm === "item" || nm === "entry")
                nodes.push(n);
            for (let i = 0; i < n.childNodes.length; i++)
                walk(n.childNodes[i]);
        }
        walk(doc.documentElement);
        for (const it of nodes) {
            const title = root._text(it, "title");
            if (title.length === 0)
                continue;
            const dateStr = root._text(it, "pubdate") || root._text(it, "updated") || root._text(it, "published") || root._text(it, "date");
            let ms = Date.parse(dateStr);
            if (isNaN(ms))
                ms = 0;
            let summary = root._text(it, "description") || root._text(it, "summary") || root._text(it, "content");
            summary = summary.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim().slice(0, 500);
            acc.push({
                "title": title,
                "link": root._linkOf(it),
                "date": ms,
                "dateStr": dateStr,
                "summary": summary,
                "source": source
            });
        }
    }

    Process {
        id: readerProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.articleLoading = false;
                try {
                    root.article = JSON.parse(text);
                } catch (e) {
                    root.article = {
                        "error": "Could not parse article"
                    };
                }
            }
        }
    }

    Timer {
        interval: Math.max(1, Config.options.sidebar.news.pollMinutes) * 60000
        repeat: true
        running: Config.ready && Config.options.sidebar.news.enable
        triggeredOnStart: false // initial fetch is deferred below to keep reloads snappy
        onTriggered: root.refresh()
    }
    // Defer the first (heavy: 8 feeds + XML parse) fetch a few seconds after load so the
    // bar paints and the reload doesn't jank from a burst of startup work.
    Timer {
        interval: 3500
        repeat: false
        running: Config.ready && Config.options.sidebar.news.enable
        onTriggered: root.refresh()
    }

    FileView {
        id: readFileView
        path: Qt.resolvedUrl(FileUtils.trimFileProtocol(`${Directories.state}/user/news_read.json`))
        onLoaded: {
            try {
                const a = JSON.parse(readFileView.text());
                let m = {};
                for (const l of a)
                    m[l] = true;
                root.readLinks = m;
            } catch (e) {}
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                readFileView.setText("[]");
        }
    }

    IpcHandler {
        target: "news"
        function refresh(): void {
            root.refresh();
        }
        function status(): string {
            return `items=${root.items.length} unread=${root.unreadCount} loading=${root.loading} reader=${root.articleUrl.length > 0}`;
        }
        function open(url: string): void {
            root.openArticle(url);
        }
        function close(): void {
            root.closeArticle();
        }
    }
}
