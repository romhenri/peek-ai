#!/bin/bash
# peek-ai: seleciona região da tela, manda pro LLM via OpenRouter, mostra tudo no Terminal e copia a resposta
# Uso: Peek.app / ./peek.sh   captura a tela e abre o Terminal com o progresso
#      ./peek.sh foto.png     usa a imagem dada, resposta no stdout (testes)
set -o pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
[ -f "$DIR/.env" ] && { set -a; . "$DIR/.env"; set +a; }
MODEL="${PEEK_MODEL:-nvidia/nemotron-3.5-super-vl:free}"
LAST="${TMPDIR:-/tmp}/peek-last.png"
PROMPT="Identifique o que é esta captura de tela e responda direto, em português, sem explicações:
- Conversa (WhatsApp, DM): sugira uma resposta curta e natural para a última mensagem.
- Email: escreva só o corpo da resposta.
- Formulário: responda cada campo no formato 'campo: resposta'.
- Comentários (Instagram etc.): uma resposta por comentário no formato '@usuario: resposta'.
- Outro: resolva o que estiver na tela."

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
  trap 'rm -f "$IMG"; echo; read -rp "Enter para fechar " _' EXIT
fi

log "📸 Captura: $(( $(stat -f %z "$IMG") / 1024 )) KB"
[ -n "$OPENROUTER_API_KEY" ] || { echo "❌ OPENROUTER_API_KEY não definida em $DIR/.env" >&2; exit 1; }

log "→ Enviando para $MODEL ..."
BODY=$(mktemp)
META=$(jq -n --arg m "$MODEL" --arg p "$PROMPT" --rawfile img <(base64 -i "$IMG") '{
  model: $m,
  messages: [{role: "user", content: [
    {type: "image_url", image_url: {url: ("data:image/png;base64," + ($img | rtrimstr("\n")))}},
    {type: "text", text: $p}]}]}' \
| curl -s --max-time 90 -o "$BODY" -w '%{http_code} %{time_total}' https://openrouter.ai/api/v1/chat/completions \
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
