#!/usr/bin/env bash
# Build, gate, rsync, Caddy, smoke. Run as `npm run deploy` from site/.
# Only the site-deployer agent runs this against the real server.
set -euo pipefail
cd "$(dirname "$0")/.."

HOST=bot
ROOT=/var/www/vitomy
VHOST=/etc/caddy/sites/vitomy.caddy
CADDYFILE=/etc/caddy/Caddyfile
IMPORT_LINE='import /etc/caddy/sites/*.caddy'
IP=45.159.220.17

echo "== build and gates"
npm run build
npm test

# macOS ships openrsync, which rejects the octal form (D755,F644); the
# symbolic form below sets the identical permissions and works on both.
CHMOD='Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r'
echo "== rsync (dry run)"
rsync -az --delete --chmod="$CHMOD" --dry-run --itemize-changes dist/ "$HOST:$ROOT/"
echo "== rsync"
rsync -az --delete --chmod="$CHMOD" --stats dist/ "$HOST:$ROOT/" | grep -E 'Number of (regular files transferred|deleted files)|Total transferred'

echo "== caddy vhost"
ssh "$HOST" "mkdir -p /etc/caddy/sites"
if ssh "$HOST" "test -f $VHOST" && diff <(ssh "$HOST" "cat $VHOST") deploy/vitomy.caddy >/dev/null; then
  echo "vhost unchanged"
else
  ssh "$HOST" "test -f $VHOST && cat $VHOST" | diff - deploy/vitomy.caddy || true
  scp -q deploy/vitomy.caddy "$HOST:$VHOST"
  echo "vhost written"
fi
if ! ssh "$HOST" "grep -qF '$IMPORT_LINE' $CADDYFILE"; then
  ssh "$HOST" "printf '\n# Sites managed one file each; see /etc/caddy/sites/.\n%s\n' '$IMPORT_LINE' >> $CADDYFILE"
  echo "import line appended to $CADDYFILE"
fi
ssh "$HOST" "caddy validate --config $CADDYFILE --adapter caddyfile >/dev/null && systemctl reload caddy"
echo "caddy reloaded"

echo "== smoke"
# The origin refuses every address outside Cloudflare's ranges, which is the
# point of putting the domain behind the proxy, so there is no way to smoke
# test the site except through Cloudflare itself. Before the A records exist
# there is nothing to test; say so rather than reporting a row of zeros that
# looks like a failure.
if [ -z "$(dig +short A vitomy.app)" ]; then
  echo "no A record for vitomy.app yet, so nothing public to test."
  echo "Add at Cloudflare: A @ -> $IP proxied, A www -> $IP proxied, then rerun."
  echo "deployed, smoke skipped"
  exit 0
fi

code() { curl -s -o /dev/null -w '%{http_code}' "https://vitomy.app$1"; }
printf '%-16s %s\n' path status
for p in / /privacy /support /terms /does-not-exist; do printf '%-16s %s\n' "$p" "$(code "$p")"; done
echo "(expect 200 200 200 404 404)"

html=$(curl -s https://vitomy.app/)
[ -n "$html" ] || { echo "the live page came back empty"; exit 1; }
grep -q '\[[A-Z_]\+\]' <<<"$html" && { echo "placeholder on the live page"; exit 1; }
grep -q -e '—' -e '–' <<<"$html" && { echo "dash on the live page"; exit 1; }
# The store links are the one sanctioned external href (same allowance as
# test/external.test.mjs); everything else on the page must be ours.
grep -oE '(src|href)="https?://[^"]+"' <<<"$html" | grep -vE 'https://(vitomy\.app/|apps\.apple\.com/|play\.google\.com/)' && { echo "external resource on the live page"; exit 1; }

# The address must not answer a direct request. A 000 (refused) is the pass.
direct=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 8 --resolve "vitomy.app:443:$IP" https://vitomy.app/ || true)
if [ "$direct" = "000" ]; then
  echo "direct hit on the origin: refused, as intended"
else
  echo "WARNING: the origin answered a direct request with $direct; the Cloudflare allowlist is not doing its job"
fi
echo "smoke clean"
