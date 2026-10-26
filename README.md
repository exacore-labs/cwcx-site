# cwcx.com — C Systems USA LLC landing page

This is the public website for **C Systems USA LLC** (DBA "C Systems"). It is a static landing page plus two legal pages, served by GitHub Pages.

- Repo: <https://github.com/exacore-labs/cwcx-site> (public, which free-plan Pages requires)
- Pages source: branch `main`, path `/`
- **Live now (2026-10-26):** <https://exacore-labs.github.io/cwcx-site/>, with HTTPS enforced
  - EULA: <https://exacore-labs.github.io/cwcx-site/terms.html>
  - Privacy policy: <https://exacore-labs.github.io/cwcx-site/privacy.html>
  - Atlas Finance forwarders: <https://exacore-labs.github.io/cwcx-site/finance/> (+ `connect/`, `disconnect/`, `qbo/callback/`)
- Custom domain: **prepared, not switched on.** Branch `cwcx-domain` holds the `CNAME` file; `./publish-domain.sh` switches it on
  after the DNS change (see **Switching on cwcx.com**). Until then `main` has no `CNAME` and serves on github.io only.
- History: the `cwcx.com` custom domain was removed on 2026-10-26 because cwcx.com's DNS still points to
  GoDaddy parking, so the github.io URLs redirected to a dead page. See **Switching on cwcx.com** below.
- Source of truth on atlas2: `/home/atlas/ATLAS2/projects/cwcx-site/`

## Files

| File | Purpose |
|---|---|
| `index.html` | The landing page. CSS is inline. It uses no JS, no trackers, no external fonts and no CDNs. |
| `terms.html` | End-user license agreement for **Atlas Finance** (the internal QuickBooks Online integration), effective 2026-10-26 |
| `privacy.html` | Privacy policy for Atlas Finance, effective 2026-10-26 |
| `404.html` | Not-found page |
| `favicon.svg` | Favicon |
| `robots.txt` | Allows all crawlers |
| `finance/**/index.html` | Atlas Finance forwarders for Intuit's app URLs (generated — see below) |
| `tools/gen-finance.py` | Generates the forwarders. Edit targets/text there, then run `python3 tools/gen-finance.py` |
| `publish-domain.sh` | Switches Pages onto cwcx.com after the DNS change (Atlas runs it) |

## Atlas Finance forwarders (`finance/`)

Atlas Finance itself stays private on the C Systems tailnet (`https://atlas2.tail73b79a.ts.net:8448`). Intuit needs public
URLs, so these static pages forward the browser there. They only work from a device on the C Systems tailnet; anyone else sees
the page note and then a connection error.

| Public URL (after DNS) | Forwards to |
|---|---|
| `https://cwcx.com/finance/` (Launch) | `https://atlas2.tail73b79a.ts.net:8448/quickbooks` |
| `https://cwcx.com/finance/connect/` (Connect / Reconnect) | `…:8448/quickbooks?tab=connection` |
| `https://cwcx.com/finance/disconnect/` (Disconnect) | `…:8448/qbo/disconnected` |
| `https://cwcx.com/finance/qbo/callback` (OAuth redirect URI) | `…:8448/qbo/callback` + the query string unchanged (`code`, `state`, `realmId`, `error`) |

Rules (enforced by `tools/gen-finance.py`): the target is a hard-coded constant, never read from the query (no open redirect);
`location.replace` (the code does not stay in history); `noindex`, `no-referrer`; a meta CSP that allows only the page's own
inline script and style by hash; no analytics or third-party scripts; a `<noscript>` link fallback; the visible note
"This is a private C Systems application. It only opens on the C Systems private network." The app validates the callback
itself (single-use hashed `state`, 10 minutes). Until the DNS change the same paths work under
`https://exacore-labs.github.io/cwcx-site/finance/…`.

There is no `CNAME` file while the custom domain is off. Links between pages are relative (`./`, `terms.html`), so they work on
both the github.io project path and cwcx.com. (`404.html` still uses root-absolute `/` links, which only resolve on cwcx.com.)

Content is limited on purpose. The landing page shows only the wordmark, the legal name, "Private company.", the contact `support@cwcx.com`, the copyright line and footer links to Terms and Privacy. Do not add claims, services, clients, team, addresses or numbers.

## Legal pages (Intuit production keys)

`terms.html` and `privacy.html` exist because Intuit's "unlock production credentials" form needs public EULA and privacy policy
URLs for the Atlas Finance QuickBooks Online app. The questionnaire draft and the app URLs are in
`/home/atlas/ATLAS2/projects/personal-finance/webapp/docs/INTUIT-PROD-KEYS.md`.

> **Not legal advice.** Atlas drafted these pages from the app's documented behaviour. They have not been reviewed by a lawyer;
> review by counsel is recommended before relying on them.

Before submitting to Intuit, Chris must:
- replace **`[State]`** in `terms.html` §9 (governing law) with the right state;
- confirm every statement still matches how the app runs. Keep the pages minimal: say nothing that is not true today
  (no certifications, no SOC 2, no claims about the hosting country).

Intuit stores these URLs, so do not rename or move the files.

## Switching on cwcx.com (after Chris changes DNS — see "DNS cutover" below)

The custom domain is ready on branch **`cwcx-domain`** (one commit: `CNAME` = `cwcx.com`). Do **not** merge it by hand before DNS
points to GitHub; otherwise the github.io URLs redirect to the GoDaddy parking page again.

When Chris says the DNS is changed, Atlas runs on atlas2:
```sh
cd /home/atlas/ATLAS2/projects/cwcx-site
./publish-domain.sh --check      # DNS preflight only: four GitHub A records, www CNAME, Google MX still there
./publish-domain.sh              # merge cwcx-domain → main, secret scan, push via m3-dev, Pages cname=cwcx.com,
                                 # wait for the certificate, enforce HTTPS, curl-verify every page
./publish-domain.sh --resume     # if the certificate wait timed out: continue from "set cname"
```
After that, GitHub redirects `https://exacore-labs.github.io/cwcx-site/<page>` to `https://cwcx.com/<page>`, so URLs already
stored at Intuit keep working. Site rollback: `echo '{"cname":null}' | ssh m3-dev 'PATH=/opt/homebrew/bin:$PATH gh api -X PUT repos/exacore-labs/cwcx-site/pages --input -'`,
then revert the merge on `main` and push. If `main` moves after `cwcx-domain` was cut, the script merges (no rebase needed).

## Updating

Edit the files here, commit, and ship via m3-dev. atlas2 has no GitHub login, so see the `github-publish` skill:

```sh
cd /home/atlas/ATLAS2/projects/cwcx-site
git -c user.name=Atlas -c user.email=atlas@cwcx.com commit -am "…"   # run a secret scan of tree + history first
git bundle create /tmp/cwcx-site.bundle --all && scp -q /tmp/cwcx-site.bundle m3-dev:/tmp/
ssh m3-dev 'cd ~/src/cwcx-site && git pull -q /tmp/cwcx-site.bundle main && git push -q'
```

Pages rebuilds automatically on every push to `main`.

---

## DNS cutover (Chris, in GoDaddy → cwcx.com → DNS)

DNS for cwcx.com stays at GoDaddy. **Do not change nameservers.** Email runs on Google Workspace, so **do not touch MX or TXT records**.

### 1. Remove
- The **A** record for `@` → `3.33.130.190`
- The **A** record for `@` → `15.197.148.33`
- Turn off any GoDaddy **Forwarding** (Domain → Forwarding) and any **Website Builder / Airo** site attached to the domain, if either exists. Either one will re-add or override the parking A records.

### 2. Add four A records (Name `@`, TTL 1 hour or default)
| Type | Name | Value |
|---|---|---|
| A | @ | 185.199.108.153 |
| A | @ | 185.199.109.153 |
| A | @ | 185.199.110.153 |
| A | @ | 185.199.111.153 |

### 3. Change
| Type | Name | Value |
|---|---|---|
| CNAME | www | exacore-labs.github.io |

(It currently points to `@`. Edit the existing record and do not add a second one.)

### 4. Leave untouched
- All **MX** records (`aspmx.l.google.com`, `alt1…alt4.aspmx.l.google.com`, etc.)
- All **TXT** records: SPF (`v=spf1 … include:_spf.google.com …`), DKIM (`google._domainkey`), DMARC (`_dmarc`), `google-site-verification`
- Any other records that are not listed above

### 5. Optional but recommended: verify the domain with GitHub
Verification stops anyone else from claiming cwcx.com on GitHub Pages. In GitHub, signed in as `exacore-labs`, go to **Settings → Pages → Add a domain** (for an org, the org Settings → Pages). Enter `cwcx.com` and GitHub shows a TXT record like `_github-pages-challenge-exacore-labs` → `<code>`. Add that TXT record in GoDaddy, then click Verify. Atlas cannot do this: the m3-dev `gh` token has no `admin:org` scope, and the challenge code only appears in the GitHub web UI.

### 6. After the DNS change: enforce HTTPS
**Tell Atlas "cwcx.com DNS changed"** — Atlas runs `./publish-domain.sh`, which does everything in this step and in
"Switching on cwcx.com". The manual commands below are the fallback.

GitHub issues a Let's Encrypt certificate once it sees the new DNS. This usually takes 15 minutes to a few hours. Check with:

```sh
dig +short cwcx.com A          # expect the four 185.199.10x.153 addresses
dig +short www.cwcx.com        # expect exacore-labs.github.io. + the 185.199.x.x addresses
dig +short cwcx.com MX         # must still list the Google aspmx hosts
ssh m3-dev 'PATH=/opt/homebrew/bin:$PATH gh api repos/exacore-labs/cwcx-site/pages --jq "{status,cname,https_certificate,https_enforced}"'
```

When `https_certificate.state` is `approved` (or `https://cwcx.com` loads without a certificate warning), enable enforcement in **repo Settings → Pages → Enforce HTTPS**, or have Atlas run:

```sh
ssh m3-dev 'PATH=/opt/homebrew/bin:$PATH gh api -X PUT repos/exacore-labs/cwcx-site/pages -f cname=cwcx.com -F https_enforced=true'
```

If the certificate stays stuck, remove the custom domain and re-add it in Settings → Pages. That triggers a new certificate request.

### Rollback
Delete the four `185.199.x.153` A records and restore the two originals:
- A `@` → `3.33.130.190`
- A `@` → `15.197.148.33`

Optionally, set `www` back to CNAME `@`. MX and TXT records never change, so email is not affected at any point.
