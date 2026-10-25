#!/bin/bash
# Testa o bridge (usa o plano local do Claude, sem custo de API): models, modelo inválido, streaming e peek.sh ponta a ponta
cd "$(dirname "$0")/.."
PORT=8799; API=http://127.0.0.1:$PORT/v1
PEEK_BRIDGE_PORT=$PORT node bridge.js >/dev/null 2>&1 & PID=$!
trap 'kill $PID 2>/dev/null' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do curl -s --max-time 1 "$API/models" >/dev/null && break; sleep 0.5; done
fail() { echo "FAIL: $1"; exit 1; }

curl -s "$API/models" | jq -e '.data | map(.id) | index("claude-code/sonnet")' >/dev/null || fail "/v1/models"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$API/chat/completions" -d '{"model":"gpt-4","messages":[]}')" = 400 ] || fail "modelo inválido deveria dar 400"

SSE=$(curl -sN --max-time 120 "$API/chat/completions" -d '{"model":"claude-code/sonnet","stream":true,"messages":[{"role":"user","content":"Responda só: ok"}]}')
grep -q '"content"' <<<"$SSE" && tail -1 <<<"$SSE" | grep -q '\[DONE\]' || fail "streaming: $SSE"
echo "stream: $(grep '^data: {' <<<"$SSE" | sed 's/^data: //' | jq -rj '.choices[0].delta.content // empty')"

OUT=$(PEEK_API=$API PEEK_MODEL=claude-code/sonnet ./peek.sh test/chat.png) || fail "peek.sh via bridge"
echo "peek: $OUT"
echo PASS
