#!/data/data/com.termux/files/usr/bin/bash
# Lisku AI - mematikan semua llama-server agar RAM bebas.
pkill llama-server 2>/dev/null
rm -f "$HOME/llm-logs/chat.pid" "$HOME/llm-logs/embed.pid"
termux-wake-unlock 2>/dev/null
echo "LISKU_OK:STOPPED"
