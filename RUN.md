# RUN.md

## Setup
```bash
echo 'OPENROUTER_API_KEY=sk-or-...' > .env
./install.sh   # Peek.app + global ⌃⌥P hotkey (LaunchAgent)
```

## Run
```bash
# ⌃⌥P in any app (or click Peek in the Dock): select a region, a Terminal window
# shows capture size, request, HTTP status, tokens and the answer (copied to clipboard)
./peek.sh
./peek.sh test/chat.png   # answer to stdout
```

## Mode
```bash
./set-mode.sh claude       # claude-code/sonnet via local bridge (Claude plan, `claude -p`)
./set-mode.sh openrouter   # nvidia/nemotron-3.5-super-vl:free
./set-mode.sh              # show current mode
node bridge.js             # manual start; peek.sh auto-starts it on 127.0.0.1:8787
```

## Test
```bash
./test/test.sh     # end-to-end in the current mode
./test/bridge.sh   # bridge: models, 400 on bad model, streaming, peek.sh via bridge
```

## Notes
- macOS only (screencapture, pbcopy, osacompile, swiftc); needs `jq` and `curl`.
- Default model `nvidia/nemotron-3.5-super-vl:free`; override with `PEEK_MODEL=...`.
- First run asks for Screen Recording permission for Peek.app.
- Uninstall hotkey: `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.peek-ai.hotkey.plist`
