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
if [ -n "$(dig +short A vitomy.app)" ]; then RESOLVE=(); else RESOLVE=(--resolve "vitomy.app:443:$IP"); echo "(no A record yet; using --resolve, TLS may fail)"; fi
code() { curl -sk -o /dev/null -w '%{http_code}' "${RESOLVE[@]}" "https://vitomy.app$1"; }
printf '%-12s %s\n' path status
for p in / /privacy /support /terms /does-not-exist; do printf '%-12s %s\n' "$p" "$(code "$p")"; done
html=$(curl -sk "${RESOLVE[@]}" https://vitomy.app/)
grep -q '\[[A-Z_]*\]' <<<"$html" && { echo "placeholder on the live page"; exit 1; }
grep -q -e '—' -e '–' <<<"$html" && { echo "dash on the live page"; exit 1; }
grep -oE '(src|href)="https?://[^"]+"' <<<"$html" | grep -vE 'https://vitomy\.app/' && { echo "external resource on the live page"; exit 1; }
echo "smoke clean"
