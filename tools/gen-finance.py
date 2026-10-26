#!/usr/bin/env python3
"""Generate the Atlas Finance forwarder pages under finance/ (run from the repo root: python3 tools/gen-finance.py).

Each page is a static, noindex page that sends the browser to the PRIVATE Atlas Finance app on the C Systems tailnet.
- The target URL is a hard-coded constant in this file. Nothing is ever taken from the query string or the fragment as a
  destination, so the pages cannot act as an open redirect.
- location.replace() is used, so the forwarder entry (and, for the OAuth callback, the code in its URL) does not stay in history.
- The callback page appends location.search unchanged (code, state, realmId, error) to its fixed target. Validation stays in
  the app (/qbo/callback: single-use hashed state, 10-minute expiry).
- No analytics, no third-party scripts, no external requests. A meta CSP allows only this page's own inline script and style
  (by sha256), the favicon, and nothing else. Referrer is suppressed.
"""
import base64
import hashlib
import pathlib

APP = "https://atlas2.tail73b79a.ts.net:8448"
NOTE = "This is a private C Systems application. It only opens on the C Systems private network."

PAGES = [
    # (path, target, keep_query, heading, noscript text)
    ("finance/index.html", f"{APP}/quickbooks", False, "Opening Atlas Finance", "Continue to Atlas Finance"),
    ("finance/connect/index.html", f"{APP}/quickbooks?tab=connection", False, "Opening the QuickBooks connection", "Continue to the QuickBooks connection page"),
    ("finance/disconnect/index.html", f"{APP}/qbo/disconnected", False, "QuickBooks disconnected", "Continue to Atlas Finance"),
    ("finance/qbo/callback/index.html", f"{APP}/qbo/callback", True, "Finishing the QuickBooks connection", "Continue to Atlas Finance"),
]

STYLE = """*{box-sizing:border-box;margin:0;padding:0}
body{background:#0a0a0b;color:#ededef;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Inter,Roboto,"Helvetica Neue",Arial,sans-serif;-webkit-font-smoothing:antialiased;min-height:100vh;min-height:100dvh;display:flex;align-items:center;justify-content:center;padding:24px;text-align:center;line-height:1.5}
main{max-width:520px}
.code{font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:#5c616b}
h1{margin-top:12px;font-size:26px;font-weight:600;letter-spacing:-0.02em}
p{margin-top:16px;font-size:15px;color:#8a8f98}
a{color:#ededef;text-decoration:none;border-bottom:1px solid #2a2d3a;padding-bottom:2px}
a:hover,a:focus-visible{border-bottom-color:#7c8cff;outline:none}"""


def sha(s: str) -> str:
    return "sha256-" + base64.b64encode(hashlib.sha256(s.encode()).digest()).decode()


def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;").replace(">", "&gt;")


def page(path: str, target: str, keep_query: bool, heading: str, noscript: str) -> str:
    depth = path.count("/")
    icon = "../" * depth + "favicon.svg"
    dest = "T+location.search" if keep_query else "T"
    script = f'(function(){{var T="{target}";location.replace({dest});}})();'
    csp = f"default-src 'none'; script-src '{sha(script)}'; style-src '{sha(STYLE)}'; img-src 'self'; base-uri 'none'; form-action 'none'"
    extra = (
        "<p>Turn on JavaScript and reload this page to pass the QuickBooks authorisation on to Atlas Finance; "
        "then start Connect again in the app if it has expired.</p>"
        if keep_query else ""
    )
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<meta name="referrer" content="no-referrer">
<meta http-equiv="Content-Security-Policy" content="{csp}">
<title>Atlas Finance · C Systems</title>
<meta name="color-scheme" content="dark">
<meta name="theme-color" content="#0a0a0b">
<link rel="icon" href="{icon}" type="image/svg+xml">
<style>{STYLE}</style>
<script>{script}</script>
</head>
<body>
  <main>
    <p class="code">Atlas Finance · C Systems</p>
    <h1>{esc(heading)}…</h1>
    <p>{esc(NOTE)}</p>
    <noscript>{extra}<p><a href="{esc(target)}">{esc(noscript)}</a></p></noscript>
  </main>
</body>
</html>
"""


if __name__ == "__main__":
    root = pathlib.Path(__file__).resolve().parent.parent
    for p, t, q, h, n in PAGES:
        f = root / p
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(page(p, t, q, h, n))
        print(f"wrote {p} -> {t}{' + location.search' if q else ''}")
