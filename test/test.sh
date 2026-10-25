#!/bin/bash
# Teste ponta a ponta no modo atual (openrouter usa o Nemotron free, claude usa o plano local): manda test/chat.png
cd "$(dirname "$0")/.."
OUT=$(./peek.sh test/chat.png) || { echo "FAIL: peek.sh saiu com erro"; exit 1; }
echo "$OUT"
[ -n "$OUT" ] && echo "PASS" || { echo "FAIL: resposta vazia"; exit 1; }
