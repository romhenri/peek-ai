#!/bin/bash
# peek-ai: seleciona região da tela, manda pro LLM via OpenRouter, mostra tudo no Terminal e copia a resposta
# Uso: Peek.app / ./peek.sh   captura a tela e abre o Terminal com o progresso
#      ./peek.sh foto.png     usa a imagem dada, resposta no stdout (testes)
set -o pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
[ -f "$DIR/.env" ] && { set -a; . "$DIR/.env"; set +a; }
[ -f "$DIR/.mode" ] && . "$DIR/.mode"   # escrito por ./set-mode.sh
API="${PEEK_API:-https://openrouter.ai/api/v1}"
MODEL="${PEEK_MODEL:-nvidia/nemotron-3.5-super-vl:free}"
LAST="${TMPDIR:-/tmp}/peek-last.png"
# prompts/<nome>.txt: PEEK_PROMPT=... vence, senão o que o atalho escreveu em .prompt, senão answer
NAME="${PEEK_PROMPT:-$(cat "$DIR/.prompt" 2>/dev/null)}"
[ -f "$DIR/prompts/$NAME.txt" ] || NAME=answer
PROMPT=$(cat "$DIR/prompts/$NAME.txt")
# ground-truth/*.md: mensagens reais suas, anexadas ao prompt como referência de tom e fatos
GT=$(cat "$DIR"/ground-truth/*.md 2>/dev/null)
# vem antes do prompt para as regras de saída serem a última coisa que o modelo lê
[ -n "$GT" ] && PROMPT="Referência (ground truth): mensagens reais minhas e como eu respondo. Siga o tom, o estilo e os fatos daqui quando forem relevantes, sem copiar literalmente:
$GT

$PROMPT"

# Sem terminal (veio do Peek.app): captura e reabre este script no Terminal, que não precisa de permissão extra
if [ -z "$1" ] && [ ! -t 1 ]; then
  rm -f "$LAST"
  screencapture -i "$LAST"; [ -s "$LAST" ] || exit 0   # ESC cancela
  open -a Terminal "$DIR/peek.sh"
  exit 0
fi

if [ -n "$1" ]; then IMG="$1"; log() { :; }
else
  log() { printf '%s\n' "$*"; }
  [ -s "$LAST" ] || { screencapture -i "$LAST"; [ -s "$LAST" ] || exit 0; }
  IMG="$LAST"
  trap 'rm -f "$IMG" "$DIR/.prompt"; echo; read -rp "Enter para fechar " _' EXIT
fi

log "📸 Captura: $(( $(stat -f %z "$IMG") / 1024 )) KB  ·  prompt: $NAME${GT:+  ·  ground truth: $(ls "$DIR"/ground-truth/*.md | wc -l | tr -d " ") md}"
if [[ "$API" == http://127.0.0.1* ]]; then
  # modo claude: sobe o bridge local se ainda não estiver no ar
  if ! curl -s --max-time 1 "$API/models" >/dev/null; then
    log "⚙︎ Subindo bridge do Claude ..."
    nohup node "$DIR/bridge.js" >>"$DIR/bridge.log" 2>&1 &
    for _ in 1 2 3 4 5 6 7 8 9 10; do curl -s --max-time 1 "$API/models" >/dev/null && break; sleep 0.5; done
  fi
else
  [ -n "$OPENROUTER_API_KEY" ] || { echo "❌ OPENROUTER_API_KEY não definida em $DIR/.env" >&2; exit 1; }
fi

log "→ Enviando para $MODEL ..."
BODY=$(mktemp)
META=$(jq -n --arg m "$MODEL" --arg p "$PROMPT" --rawfile img <(base64 -i "$IMG") '{
  model: $m,
  messages: [{role: "user", content: [
    {type: "image_url", image_url: {url: ("data:image/png;base64," + ($img | rtrimstr("\n")))}},
    {type: "text", text: $p}]}]}' \
| curl -s --max-time 120 -o "$BODY" -w '%{http_code} %{time_total}' "$API/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" -H "Content-Type: application/json" -H "X-Title: peek-ai" -d @-)
read -r CODE SECS <<<"$META"
log "← HTTP $CODE em ${SECS}s"

OUT=$(jq -r '.choices[0].message.content // empty' "$BODY" 2>/dev/null)
if [ -z "$OUT" ]; then
  echo "❌ Sem resposta. Corpo recebido:" >&2; cat "$BODY" >&2; [ "$CODE" = 000 ] && echo "(falha de rede ou timeout)" >&2
  rm -f "$BODY"; exit 1
fi
log "   tokens: $(jq -r '.usage | "\(.prompt_tokens) entrada / \(.completion_tokens) saída"' "$BODY" 2>/dev/null)"
rm -f "$BODY"

if [ -n "$1" ]; then printf '%s\n' "$OUT"; exit 0; fi
printf %s "$OUT" | pbcopy
printf '\n───────── resposta ─────────\n%s\n────────────────────────────\n✓ Copiado para o clipboard\n' "$OUT"
