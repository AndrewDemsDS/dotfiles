#!/usr/bin/env python3
"""Extract a readable article (text + images) from a URL using trafilatura.

Outputs JSON: { url, title, author, date, sitename, blocks: [{type:text,md} | {type:image,url}] }
Run via read-article.sh (which selects the reader venv). Requires `trafilatura`.
"""
import sys
import json
import re


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "no url"}))
        return
    url = sys.argv[1]
    try:
        import trafilatura
    except ImportError:
        print(json.dumps({"error": "trafilatura not installed"}))
        return

    downloaded = trafilatura.fetch_url(url)
    if not downloaded:
        print(json.dumps({"error": "fetch failed", "url": url}))
        return

    md = trafilatura.extract(
        downloaded, output_format="markdown", with_metadata=True,
        include_images=True, include_links=True, favor_recall=True,
    ) or ""

    # Split YAML-ish front matter trafilatura prepends with --with-metadata
    meta, body = {}, md
    if md.startswith("---"):
        parts = md.split("---", 2)
        if len(parts) >= 3:
            for line in parts[1].strip().splitlines():
                if ":" in line:
                    k, v = line.split(":", 1)
                    meta[k.strip()] = v.strip()
            body = parts[2]

    # Parse body into ordered text/image blocks
    blocks, buf = [], []
    img_re = re.compile(r"^\s*!\[[^\]]*\]\((\S+?)\)\s*$")

    def flush():
        if buf:
            text = "\n".join(buf).strip()
            if text:
                blocks.append({"type": "text", "md": text})
            buf.clear()

    for line in body.splitlines():
        m = img_re.match(line)
        if m and m.group(1).startswith("http"):
            flush()
            blocks.append({"type": "image", "url": m.group(1)})
        else:
            buf.append(line)
    flush()

    print(json.dumps({
        "url": url,
        "title": meta.get("title", ""),
        "author": meta.get("author", ""),
        "date": meta.get("date", ""),
        "sitename": meta.get("sitename", meta.get("hostname", "")),
        "blocks": blocks,
    }, ensure_ascii=False))


main()
