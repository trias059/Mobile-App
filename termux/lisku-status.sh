#!/data/data/com.termux/files/usr/bin/bash
# Lisku AI - laporan status singkat untuk aplikasi (dibaca lewat RUN_COMMAND).
LOGS="$HOME/llm-logs"

alive() {
  local pid
  pid="$(cat "$LOGS/$1.pid" 2>/dev/null)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then echo 1; else echo 0; fi
}

echo "CHAT_ALIVE=$(alive chat)"
echo "EMBED_ALIVE=$(alive embed)"
echo "MODEL=$(tr -d '[:space:]' < "$HOME/.lisku-model" 2>/dev/null)"
echo "---CHAT_LOG---"
tail -n 25 "$LOGS/chat.log" 2>/dev/null
echo "---EMBED_LOG---"
tail -n 10 "$LOGS/embed.log" 2>/dev/null
