#!/data/data/com.termux/files/usr/bin/bash
# Lisku AI - menyalakan llama-server di background.
#   Chat      : http://127.0.0.1:8080  (thinking -> reasoning_content)
#   Embedding : http://127.0.0.1:8081/v1/embeddings
# Model aktif dibaca dari ~/.lisku-model (default | uncensored).

MODELS="$HOME/models"
LOGS="$HOME/llm-logs"
mkdir -p "$MODELS" "$LOGS"

CHOICE="$(tr -d '[:space:]' < "$HOME/.lisku-model" 2>/dev/null)"
[ -z "$CHOICE" ] && CHOICE=default

if ! command -v llama-server >/dev/null 2>&1; then
  echo "LISKU_ERR:NO_LLAMA"
  exit 4
fi

# Pakai file lokal di ~/models bila ada, kalau tidak biarkan llama-server
# mengunduh sendiri lewat -hf (masuk ke cache llama.cpp).
#   $1 = kunci (nama file .path), $2 = repo:quant, $3 = path file tetap (opsional)
model_args() {
  local file="$3"
  if [ -z "$file" ] && [ -f "$MODELS/$1.path" ]; then
    file="$MODELS/$(cat "$MODELS/$1.path")"
  fi
  if [ -n "$file" ] && [ -f "$file" ] && [ ! -f "$file.lisku-partial" ]; then
    echo "-m $file"
  else
    echo "-hf $2"
  fi
}

case "$CHOICE" in
  uncensored)
    CHAT=( $(model_args chat-uncensored "TrevorJS/gemma-4-E2B-it-uncensored-GGUF:Q4_K_M" "") )
    ;;
  *)
    CHOICE=default
    CHAT=( $(model_args chat-default "ggml-org/Qwen3-1.7B-GGUF:Q4_K_M" "$MODELS/Qwen3-1.7B-Q4_K_M.gguf") )
    ;;
esac
EMB=( $(model_args embed "ggml-org/embeddinggemma-300M-GGUF:Q8_0" "") )

# Matikan instance lama dulu agar port bebas.
pkill llama-server 2>/dev/null
sleep 1

# Jaga Termux tetap hidup selama server berjalan.
termux-wake-lock 2>/dev/null

echo "$CHOICE" > "$LOGS/active-model"

nohup llama-server "${CHAT[@]}" \
  --host 127.0.0.1 --port 8080 \
  -c 4096 -t 6 \
  --jinja --reasoning-format deepseek \
  > "$LOGS/chat.log" 2>&1 < /dev/null &
echo $! > "$LOGS/chat.pid"

nohup llama-server "${EMB[@]}" \
  --host 127.0.0.1 --port 8081 \
  --embedding -c 2048 -b 2048 -ub 2048 -t 2 \
  > "$LOGS/embed.log" 2>&1 < /dev/null &
echo $! > "$LOGS/embed.pid"

echo "LISKU_OK:STARTED:$CHOICE"
