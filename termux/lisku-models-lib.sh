#!/data/data/com.termux/files/usr/bin/bash
# Lisku AI - fungsi bersama untuk mengunduh model (di-source oleh
# setup-lisku-ai.sh dan download-uncensored.sh). Pemanggil wajib
# mendefinisikan fungsi fail() dan boleh mengisi LISKU_RETRY_HINT.

MODELS="$HOME/models"

# Cari nama file .gguf untuk kuantisasi tertentu lewat API Hugging Face.
hf_file() {
  curl -fsSL "https://huggingface.co/api/models/$1/tree/main" \
    | grep -o '"path":"[^"]*\.gguf"' | cut -d'"' -f4 \
    | grep -i "$2" | grep -vi mmproj | head -n1
}

# Unduh model dengan resume (wget -c). Selama unduhan berlangsung ada penanda
# <file>.lisku-partial; penanda baru dihapus setelah unduhan lengkap.
#   $1 = kunci, $2 = repo, $3 = kuantisasi, $4 = nama file lokal tetap (opsional)
download() {
  local key="$1" repo="$2" quant="$3" local_name="$4" remote target
  mkdir -p "$MODELS"
  if [ -n "$local_name" ] && [ -f "$MODELS/$local_name" ] \
     && [ ! -f "$MODELS/$local_name.lisku-partial" ]; then
    echo "   [ada] ~/models/$local_name - dipakai"
    echo "$local_name" > "$MODELS/$key.path"
    return
  fi

  remote="$(hf_file "$repo" "$quant")"
  [ -z "$remote" ] && remote="$local_name"
  [ -z "$remote" ] && fail "File $quant tidak ditemukan di $repo (cek internet)."
  [ -z "$local_name" ] && local_name="$(basename "$remote")"
  target="$MODELS/$local_name"

  # Catat nama file lebih dulu agar unduhan yang terputus bisa dilanjutkan.
  echo "$local_name" > "$MODELS/$key.path"

  if [ -f "$target" ] && [ ! -f "$target.lisku-partial" ]; then
    echo "   [ada] ~/models/$local_name - dipakai"
  else
    echo "   [unduh] $repo -> ~/models/$local_name"
    touch "$target.lisku-partial"
    wget -c --tries=5 -q --show-progress -O "$target" \
      "https://huggingface.co/$repo/resolve/main/$remote" \
      || fail "Unduhan $local_name terputus. ${LISKU_RETRY_HINT:-Ulangi untuk melanjutkan.}"
    rm -f "$target.lisku-partial"
  fi
}

# Return 0 jika model dengan kunci $1 sudah terunduh lengkap.
model_complete() {
  local name
  name="$(cat "$MODELS/$1.path" 2>/dev/null)"
  [ -n "$name" ] && [ -f "$MODELS/$name" ] && [ ! -f "$MODELS/$name.lisku-partial" ]
}
