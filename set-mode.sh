#!/bin/bash
# Alterna o backend do Peek: ./set-mode.sh openrouter | claude   (sem argumento mostra o modo atual)
cd "$(dirname "$0")"
case "$1" in
  openrouter) API=https://openrouter.ai/api/v1; MODEL=nvidia/nemotron-3.5-super-vl:free ;;
  claude)     API=http://127.0.0.1:8787/v1;     MODEL=claude-code/sonnet ;;
  "") [ -f .mode ] && sed -n 's/^# //p' .mode || echo "modo: openrouter (padrão)"; exit 0 ;;
  *) echo "uso: $0 openrouter|claude"; exit 1 ;;
esac
# := só preenche o que não veio do ambiente, então PEEK_MODEL=... ./peek.sh continua valendo
printf '# modo: %s\n: "${PEEK_API:=%s}"\n: "${PEEK_MODEL:=%s}"\n' "$1" "$API" "$MODEL" > .mode
echo "modo: $1 ($MODEL)"
if [ "$1" = claude ]; then echo "O bridge sobe sozinho na primeira captura (log em bridge.log)."; fi
