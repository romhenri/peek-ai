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

## Test
```bash
./test/test.sh   # end-to-end on the free model
```

## Notes
- macOS only (screencapture, pbcopy, osacompile, swiftc); needs `jq` and `curl`.
- Default model `nvidia/nemotron-3.5-super-vl:free`; override with `PEEK_MODEL=...`.
- First run asks for Screen Recording permission for Peek.app.
- Uninstall hotkey: `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.peek-ai.hotkey.plist`
