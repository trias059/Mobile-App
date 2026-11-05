#!/data/data/com.termux/files/usr/bin/bash
# Lisku AI - setup sekali jalan (dikirim aplikasi Lisku lewat RUN_COMMAND,
# berjalan di sesi FOREGROUND Termux agar progres terlihat).
#
# Sebelum bagian ini, aplikasi sudah menulis ~/start-llm.sh, ~/stop-llm.sh,
# ~/lisku-status.sh, ~/lisku-models-lib.sh, dan ~/download-uncensored.sh.
# Untuk menjalankan manual: salin file-file itu ke ~ lalu jalankan:
# bash setup-lisku-ai.sh

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
for f in start-llm.sh stop-llm.sh lisku-status.sh lisku-models-lib.sh download-uncensored.sh; do
  [ -f "$HOME/$f" ] || fail "~/$f belum ada."
  chmod +x "$HOME/$f"
done
[ -s "$HOME/.lisku-model" ] || echo default > "$HOME/.lisku-model"
echo "   Model aktif: $(cat "$HOME/.lisku-model")"

step "4/5 Mengunduh model default & embedding (bisa dilanjutkan jika terputus)"

# shellcheck source=lisku-models-lib.sh
. "$HOME/lisku-models-lib.sh" || fail "~/lisku-models-lib.sh belum ada."
LISKU_RETRY_HINT="Tekan Setup AI lagi untuk melanjutkan."

# Model uncensored (±3,4 GB) TIDAK diunduh di sini; hanya saat dipilih di
# Pengaturan AI (lihat download-uncensored.sh).
download chat-default "ggml-org/Qwen3-1.7B-GGUF"          "Q4_K_M" "Qwen3-1.7B-Q4_K_M.gguf"
download embed        "ggml-org/embeddinggemma-300M-GGUF" "Q8_0"   ""

step "5/5 Pemeriksaan"
llama-server --version 2>&1 | head -n 2
ls -lh "$HOME/models"/*.gguf
date > "$HOME/.lisku-setup-ok"
termux-wake-unlock 2>/dev/null

echo
echo "SELESAI! Kembali ke aplikasi Lisku dan buka halaman AI."
echo "Sesi ini boleh ditutup."
