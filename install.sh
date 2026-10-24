#!/bin/bash
# Cria /Applications/Peek.app (a chave vem do .env desta pasta)
cd "$(dirname "$0")" && DIR=$(pwd)
chmod +x peek.sh
grep -q '^OPENROUTER_API_KEY=' .env 2>/dev/null || { echo "Crie .env com OPENROUTER_API_KEY=sk-or-..."; exit 1; }
mkdir -p /Applications
osacompile -o /Applications/Peek.app -e "do shell script quoted form of \"$DIR/peek.sh\""
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.peek-ai.peek" /Applications/Peek.app/Contents/Info.plist
codesign -f -s - /Applications/Peek.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Peek.app
mdimport /Applications/Peek.app

# Atalho global ⌃⌥P: daemon em ~/Library/LaunchAgents, sobe sozinho no login
swiftc -swift-version 5 -O hotkey.swift -o peek-hotkey
PLIST=~/Library/LaunchAgents/com.peek-ai.hotkey.plist
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.peek-ai.hotkey</string>
<key>ProgramArguments</key><array><string>$DIR/peek-hotkey</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
</dict></plist>
PL
launchctl bootout gui/$(id -u) "$PLIST" 2>/dev/null
launchctl bootstrap gui/$(id -u) "$PLIST"
echo "Pronto: ⌃⌥P em qualquer app, ou clique no Peek no Dock."
