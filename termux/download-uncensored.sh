#!/data/data/com.termux/files/usr/bin/bash
# Lisku AI - unduh model chat uncensored (Gemma 4 E2B, Q4_K_M, ±3,4 GB).
# Dijalankan aplikasi Lisku di sesi FOREGROUND Termux hanya saat user memilih
# model "Uncensored" di Pengaturan. Bisa dilanjutkan bila terputus.
# Tidak mengubah ~/.lisku-model: itu dilakukan aplikasi setelah unduhan sukses.

fail() {
  echo
  echo "GAGAL: $*"
  echo "Lisku tetap memakai model default."
  echo "Tekan Enter untuk menutup..."
  read -r _
  exit 1
}

# shellcheck source=lisku-models-lib.sh
. "$HOME/lisku-models-lib.sh" 2>/dev/null || fail "~/lisku-models-lib.sh belum ada. Jalankan Setup AI dulu."
LISKU_RETRY_HINT="Pilih Uncensored lagi di Pengaturan AI untuk melanjutkan."

echo "========================================"
echo "   Lisku AI - Unduh model Uncensored    "
echo "========================================"

termux-wake-lock 2>/dev/null
download chat-uncensored "TrevorJS/gemma-4-E2B-it-uncensored-GGUF" "Q4_K_M" ""
model_complete chat-uncensored || fail "File model belum lengkap."
termux-wake-unlock 2>/dev/null

echo
echo "SELESAI! Kembali ke Lisku; model Uncensored akan dinyalakan."
echo "Sesi ini boleh ditutup."
