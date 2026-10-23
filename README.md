# cwcx.com — C Systems USA LLC landing page

This is the public website for **C Systems USA LLC** (DBA "C Systems") at <https://cwcx.com>. It is one static page, served by GitHub Pages.

- Repo: <https://github.com/exacore-labs/cwcx-site> (public, which free-plan Pages requires)
- Pages source: branch `main`, path `/`
- Custom domain: `cwcx.com`, set by the `CNAME` file and the Pages API
- Source of truth on atlas2: `/home/atlas/ATLAS2/projects/cwcx-site/`

## Files

| File | Purpose |
|---|---|
| `index.html` | The page. CSS is inline. It uses no JS, no trackers, no external fonts and no CDNs. |
| `404.html` | Not-found page |
| `favicon.svg` | Favicon |
| `CNAME` | `cwcx.com`, the GitHub Pages custom domain |
| `robots.txt` | Allows all crawlers |

Content is limited on purpose. It shows only the wordmark, the legal name, "Private company.", the contact `support@cwcx.com` and the copyright line. Do not add claims, services, clients, team, addresses or numbers.

## Updating

Edit the files here, commit, and ship via m3-dev. atlas2 has no GitHub login, so see the `github-publish` skill:

```sh
cd /home/atlas/ATLAS2/projects/cwcx-site
git -c user.name=Atlas -c user.email=atlas@cwcx.com commit -am "…"
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
