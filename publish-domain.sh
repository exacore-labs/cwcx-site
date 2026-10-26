#!/usr/bin/env bash
# publish-domain.sh — switch GitHub Pages for exacore-labs/cwcx-site onto https://cwcx.com.
# Atlas runs this on atlas2 ONLY after Chris has made the GoDaddy DNS change in README.md ("DNS cutover").
#
#   ./publish-domain.sh --check     DNS preflight only (changes nothing)
#   ./publish-domain.sh             preflight → merge branch cwcx-domain (adds CNAME) into main → secret scan → push via m3-dev
#                                   → Pages cname=cwcx.com → wait for the certificate → enforce HTTPS → verify
#   ./publish-domain.sh --resume    skip the merge/push (already done) and continue from "set cname"
#
# It never touches DNS. atlas2 has no GitHub login: every GitHub call runs through m3-dev's gh (github-publish skill).
# Rollback (site side): echo '{"cname":null}' | ssh m3-dev 'PATH=/opt/homebrew/bin:$PATH gh api -X PUT repos/exacore-labs/cwcx-site/pages --input -'
# then `git revert` the merge on main and push; DNS rollback is in README.md.
set -euo pipefail

REPO=exacore-labs/cwcx-site
DOMAIN=cwcx.com
GH_IPS="185.199.108.153 185.199.109.153 185.199.110.153 185.199.111.153"
HERE="$(cd "$(dirname "$0")" && pwd)"
GH() { ssh -o BatchMode=yes m3-dev "export PATH=/opt/homebrew/bin:\$PATH; $*"; }
say() { printf '== %s\n' "$*"; }
die() { printf 'ABORT: %s\n' "$*" >&2; exit 1; }

MODE="${1:-run}"
cd "$HERE"

# ---------------------------------------------------------------- 1. DNS preflight (public resolvers)
preflight() {
  local ok=1 r a www mx
  for r in 1.1.1.1 8.8.8.8; do
    a="$(dig +short @"$r" "$DOMAIN" A | sort | tr '\n' ' ' | sed 's/ $//')"
    www="$(dig +short @"$r" "www.$DOMAIN" CNAME | sed 's/\.$//')"
    mx="$(dig +short @"$r" "$DOMAIN" MX | tr '\n' ' ')"
    echo "resolver $r: A=[$a] www CNAME=[$www] MX=[$mx]"
    [ "$a" = "$GH_IPS" ] || { echo "  ✗ apex A records are not exactly the four GitHub Pages IPs"; ok=0; }
    [ "$www" = "exacore-labs.github.io" ] || { echo "  ✗ www is not CNAME exacore-labs.github.io"; ok=0; }
    echo "$mx" | grep -qi 'google' || { echo "  ✗ MX no longer lists Google (email!) — stop and check GoDaddy"; ok=0; }
  done
  [ "$ok" = 1 ] || return 1
  echo "  ✓ DNS points to GitHub Pages, Google MX intact"
}

say "DNS preflight"
if ! preflight; then
  [ "$MODE" = "--check" ] && exit 1
  die "DNS is not ready (or not yet propagated). Re-run later; nothing was changed."
fi
[ "$MODE" = "--check" ] && exit 0

# ---------------------------------------------------------------- 2. merge cwcx-domain → main, scan, push
if [ "$MODE" != "--resume" ]; then
  say "merge branch cwcx-domain into main"
  [ -z "$(git status --porcelain)" ] || die "working tree not clean"
  git checkout -q main
  git rev-parse -q --verify cwcx-domain >/dev/null || die "branch cwcx-domain missing"
  git -c user.name=Atlas -c user.email=atlas@cwcx.com merge --no-edit cwcx-domain
  [ "$(cat CNAME)" = "$DOMAIN" ] || die "CNAME on main is not $DOMAIN"

  say "secret scan (tree + history)"
  PAT='(api[_-]?key|secret|passw(or)?d|token|bearer|private[_-]?key)["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9_\-]{16,}|BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|oc-sent-'
  # shellcheck disable=SC2046
  if git grep -nIE "$PAT" $(git rev-list --all) -- . ':!publish-domain.sh' >/dev/null 2>&1; then
    git grep -nIE "$PAT" $(git rev-list --all) -- . ':!publish-domain.sh' | head -5
    die "secret scan hit — not pushed"
  fi
  echo "  ✓ clean"

  say "push main via m3-dev"
  B=/tmp/cwcx-site.bundle
  git bundle create -q "$B" --all && scp -q "$B" m3-dev:/tmp/
  GH "cd ~/src/cwcx-site && git checkout -q main && git pull -q --ff-only $B main && git push -q origin main && git log -1 --format=%h"
fi

# ---------------------------------------------------------------- 3. Pages custom domain + certificate + HTTPS
say "set Pages cname=$DOMAIN"
GH "gh api -X PUT repos/$REPO/pages -f cname=$DOMAIN" >/dev/null
say "wait for the certificate (up to ~3 h, every 2 min)"
state=""
for _ in $(seq 1 90); do
  state="$(GH "gh api repos/$REPO/pages --jq '.https_certificate.state // \"none\"'" 2>/dev/null || echo error)"
  echo "  $(date -u +%H:%M:%SZ) certificate: $state"
  [ "$state" = "approved" ] && break
  sleep 120
done
[ "$state" = "approved" ] || die "certificate not approved yet (state $state). Re-run: ./publish-domain.sh --resume  (if stuck: README 'enforce HTTPS')"

say "enforce HTTPS"
GH "gh api -X PUT repos/$REPO/pages -f cname=$DOMAIN -F https_enforced=true" >/dev/null
GH "gh api repos/$REPO/pages --jq '{status,cname,https_enforced,cert:.https_certificate.state}'"

# ---------------------------------------------------------------- 4. verify
say "verify"
sleep 30
fail=0
for p in / terms.html privacy.html finance/ finance/connect/ finance/disconnect/ finance/qbo/callback/; do
  c="$(curl -s -o /dev/null -w '%{http_code}' "https://$DOMAIN/$p")"
  echo "  https://$DOMAIN/$p → $c"
  [ "$c" = 200 ] || fail=1
done
c="$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' "https://$DOMAIN/finance/qbo/callback?code=x&state=y&realmId=1")"
echo "  https://$DOMAIN/finance/qbo/callback?… → $c   (a 301 must keep the query)"
c="$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' "https://exacore-labs.github.io/cwcx-site/privacy.html")"
echo "  github.io privacy.html → $c   (expect 301 → https://$DOMAIN/privacy.html)"
c="$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' "http://$DOMAIN/")"
echo "  http://$DOMAIN/ → $c   (expect 301 → https)"
[ "$fail" = 0 ] || die "a page did not return 200 — check above"
say "done: https://$DOMAIN is live. Tell Chris; the Intuit URLs in docs/INTUIT-PROD-KEYS.md are now active."
