#!/bin/bash
# 局を GitHub Pages に公開する：gh-pages ブランチを「main の中身＋直近の音声」のコミット 1 つで上書きする。
# 音声は git の履歴に入らない（古い音声は履歴ごと消える）。直近の日数と音声のフォルダは station.json の audio（既定 30 日、audio/）。
# usage: tools/publish.sh   （局のリポジトリの中で。origin に push できること）
# 共有カード（share/）も作る：Pillow のある python を SHARE_PYTHON に、日本語の入ったフォントを SHARE_FONT に（tools/share.py）
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
PY=python3
if ! "$PY" --version >/dev/null 2>&1; then PY=python; fi
if ! "$PY" --version >/dev/null 2>&1; then
  echo "Python 3 is required (python3 or python)." >&2
  exit 1
fi
export PYTHONUTF8=1
read -r DIR KEEP < <("$PY" -c 'import json; a = json.load(open("station.json")).get("audio", {}); print(a.get("dir", "audio"), a.get("keep_days", 30))')
CUT=$("$PY" -c "import datetime; print((datetime.date.today() - datetime.timedelta(days=$KEEP)).isoformat())")
REMOTE=$(git remote get-url origin)
NAME=$(git config user.name || echo myradio); EMAIL=$(git config user.email || echo myradio@users.noreply.github.com)

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
git archive HEAD | tar -x -C "$TMP"              # what main has (committed)
mkdir -p "$TMP/$DIR"
n=0
for f in "$DIR"/*; do                            # audio files named <YYYY-MM-DD>...; keep the recent ones
  [ -e "$f" ] || continue
  d=$(basename "$f"); d=${d:0:10}
  if [[ ! "$d" < "$CUT" ]]; then cp "$f" "$TMP/$DIR/"; n=$((n + 1)); fi
done
# share cards (tools/share.py) when Pillow is there: SHARE_PYTHON picks the python, SHARE_FONT the font
PY=${SHARE_PYTHON:-$PY}
if [[ -z "${SHARE_FONT:-}" && ! -f "$TMP/fonts/NotoSansJP.ttf" && -n "${WINDIR:-}" ]]; then
  FONT="$(cygpath -m "$WINDIR")/Fonts/meiryo.ttc"
  if [[ -f "$FONT" ]]; then export SHARE_FONT="$FONT"; fi
fi
if "$PY" -c "import PIL" 2>/dev/null; then "$PY" tools/share.py "$TMP" --all --front; else echo "share cards: skipped (no Pillow)"; fi
touch "$TMP/.nojekyll"                           # serve files as they are
cd "$TMP"
git init -q -b gh-pages
git add -A -f                                     # the audio too (the copied .gitignore keeps it off main only)
git -c user.name="$NAME" -c user.email="$EMAIL" commit -q -m "publish $(date +%F)"
git push -q -f "$REMOTE" gh-pages
echo "published gh-pages: $(git ls-files | wc -l | tr -d ' ') files, $n audio (since $CUT)"
