#!/bin/bash
# Teste ponta a ponta com o modelo free (custo zero): manda test/chat.png e confere a resposta
cd "$(dirname "$0")/.."
OUT=$(PEEK_MODEL="${PEEK_MODEL:-nvidia/nemotron-3.5-super-vl:free}" ./peek.sh test/chat.png) || { echo "FAIL: peek.sh saiu com erro"; exit 1; }
echo "$OUT"
[ -n "$OUT" ] && echo "PASS" || { echo "FAIL: resposta vazia"; exit 1; }
