#!/data/data/com.termux/files/usr/bin/bash
# Lisku AI - setup sekali jalan (dikirim aplikasi Lisku lewat RUN_COMMAND,
# berjalan di sesi FOREGROUND Termux agar progres terlihat).
#
# Sebelum bagian ini, aplikasi sudah menulis ~/start-llm.sh, ~/stop-llm.sh,
# dan ~/lisku-status.sh. Untuk menjalankan manual: salin ketiga file itu ke ~
# lalu jalankan: bash setup-lisku-ai.sh

step() { echo; echo "==> $*"; }
fail() {
  echo
  echo "GAGAL: $*"
  echo "Tekan Enter untuk menutup..."
  read -r _
  exit 1
}

echo "========================================"
echo "        Lisku AI - Setup Otomatis       "
echo "========================================"

termux-wake-lock 2>/dev/null

step "1/5 Memasang llama-cpp, wget, curl"
pkg install -y llama-cpp wget curl || fail "pkg install gagal. Cek koneksi internet lalu ulangi Setup AI."
command -v llama-server >/dev/null 2>&1 || fail "llama-server tidak ditemukan setelah pemasangan."

step "2/5 Menyiapkan folder ~/models dan ~/llm-logs"
mkdir -p "$HOME/models" "$HOME/llm-logs"

step "3/5 Menyiapkan skrip & pilihan model"
for f in start-llm.sh stop-llm.sh lisku-status.sh; do
  [ -f "$HOME/$f" ] || fail "~/$f belum ada."
  chmod +x "$HOME/$f"
done
[ -s "$HOME/.lisku-model" ] || echo default > "$HOME/.lisku-model"
echo "   Model aktif: $(cat "$HOME/.lisku-model")"

step "4/5 Mengunduh model (bisa dilanjutkan jika terputus)"

# Cari nama file .gguf untuk kuantisasi tertentu lewat API Hugging Face.
hf_file() {
  curl -fsSL "https://huggingface.co/api/models/$1/tree/main" \
    | grep -o '"path":"[^"]*\.gguf"' | cut -d'"' -f4 \
    | grep -i "$2" | grep -vi mmproj | head -n1
}

#   $1 = kunci, $2 = repo, $3 = kuantisasi, $4 = nama file lokal tetap (opsional)
download() {
  local key="$1" repo="$2" quant="$3" local_name="$4" remote target
  if [ -n "$local_name" ] && [ -f "$HOME/models/$local_name" ] \
     && [ ! -f "$HOME/models/$local_name.lisku-partial" ]; then
    echo "   [ada] ~/models/$local_name - dipakai"
    echo "$local_name" > "$HOME/models/$key.path"
    return
  fi

  remote="$(hf_file "$repo" "$quant")"
  [ -z "$remote" ] && remote="$local_name"
  [ -z "$remote" ] && fail "File $quant tidak ditemukan di $repo (cek internet)."
  [ -z "$local_name" ] && local_name="$(basename "$remote")"
  target="$HOME/models/$local_name"

  if [ -f "$target" ] && [ ! -f "$target.lisku-partial" ]; then
    echo "   [ada] ~/models/$local_name - dipakai"
  else
    echo "   [unduh] $repo -> ~/models/$local_name"
    touch "$target.lisku-partial"
    wget -c --tries=5 -q --show-progress -O "$target" \
      "https://huggingface.co/$repo/resolve/main/$remote" \
      || fail "Unduhan $local_name terputus. Tekan Setup AI lagi untuk melanjutkan."
    rm -f "$target.lisku-partial"
  fi
  echo "$local_name" > "$HOME/models/$key.path"
}

download chat-default    "ggml-org/Qwen3-1.7B-GGUF"                 "Q4_K_M" "Qwen3-1.7B-Q4_K_M.gguf"
download embed           "ggml-org/embeddinggemma-300M-GGUF"        "Q8_0"   ""
download chat-uncensored "TrevorJS/gemma-4-E2B-it-uncensored-GGUF"  "Q4_K_M" ""

step "5/5 Pemeriksaan"
llama-server --version 2>&1 | head -n 2
ls -lh "$HOME/models"/*.gguf
date > "$HOME/.lisku-setup-ok"
termux-wake-unlock 2>/dev/null

echo
echo "SELESAI! Kembali ke aplikasi Lisku dan buka halaman AI."
echo "Sesi ini boleh ditutup."
