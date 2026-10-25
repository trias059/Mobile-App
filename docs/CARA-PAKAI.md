# Cara Pakai Asisten AI Lisku

Panduan dari memasang APK sampai chat pertama. AI berjalan **offline di HP** lewat Termux
(llama.cpp). Diuji untuk Asus Zenfone 11 Ultra (RAM 12 GB); HP lain dengan RAM ≥ 8 GB
seharusnya bisa memakai model default.

Butuh: ruang kosong **±5 GB** (model ±4,5 GB) dan internet (Wi-Fi) **hanya saat Setup AI**.

---

## 1. Build & pasang APK

Di komputer (Flutter SDK + Android SDK terpasang):

```bash
flutter pub get
flutter build apk --release
```

File APK: `build/app/outputs/flutter-apk/app-release.apk`. Salin ke HP lalu buka untuk
memasang (izinkan "Install dari sumber tidak dikenal" bila diminta).

## 2. Pasang & siapkan Termux

1. Pasang **Termux dari F-Droid** (<https://f-droid.org/packages/com.termux/>) atau
   GitHub Releases (<https://github.com/termux/termux-app/releases>).
   Jangan campur dengan Termux dari Play Store (tanda tangan berbeda).
2. Buka Termux sekali sampai muncul prompt `$`.
3. Izinkan aplikasi lain (Lisku) mengirim perintah. Ketik di Termux:

   ```bash
   mkdir -p ~/.termux && echo "allow-external-apps=true" >> ~/.termux/termux.properties && termux-reload-settings
   ```

4. Disarankan (agar AI tidak dimatikan Android):
   - Pengaturan HP > Aplikasi > Termux > Baterai > **Tidak dibatasi**.
   - Pengaturan HP > Aplikasi > Termux > **Tampilkan di atas aplikasi lain** > izinkan
     (agar sesi Setup bisa langsung terbuka dari Lisku).
   - Android 14+: Opsi pengembang > **Nonaktifkan batasan proses turunan**
     (*Disable child process restrictions*), bila ada.

## 3. Izinkan Lisku memakai Termux

1. Buka **Lisku** > tab **AI** (atau menu cepat **Asisten AI** di Dashboard).
2. Muncul kartu "Lisku perlu izin ..." > tekan **Beri Izin** > baca penjelasan >
   **Beri Izin** > pada dialog Android pilih **Izinkan**
   (*Run commands in Termux environment*).

Jika terlanjur menolak: Pengaturan > Aplikasi > Lisku > Izin > Izin tambahan >
*Run commands in Termux environment* > Izinkan.

## 4. Setup AI (sekali saja)

1. Di halaman AI tekan **Setup AI**. Termux terbuka dan menampilkan progres:
   1. `pkg install -y llama-cpp wget curl`
   2. membuat `~/models` dan `~/llm-logs`
   3. menulis `~/start-llm.sh`, `~/stop-llm.sh`, `~/lisku-status.sh`, `~/.lisku-model`
   4. mengunduh 3 model (Qwen3 1.7B, EmbeddingGemma 300M, Gemma 4 E2B uncensored)
   5. pemeriksaan
2. Tunggu sampai tertulis **SELESAI!**. Jika unduhan terputus, tekan **Setup AI** lagi —
   unduhan dilanjutkan (resume), bukan dari nol.
3. Kembali ke Lisku. Jika `~/models/Qwen3-1.7B-Q4_K_M.gguf` sudah ada sebelumnya, file itu
   langsung dipakai dan tidak diunduh ulang.

## 5. Chat pertama

1. Buka tab **AI**. Status berubah: *Menyalakan AI...* > *Memuat model ke RAM...* >
   **AI siap dipakai** (±5–20 detik).
2. Pilih **Penasihat**, ketik misalnya *"Lebih baik nabung emas atau reksa dana untuk 1 tahun?"*,
   tekan kirim.
3. Selama model berpikir muncul animasi **Thinking...**. Lalu jawaban muncul per kata.
4. Tekan **Lihat proses berpikir** di bawah jawaban untuk membuka isi pikirannya
   (tersembunyi secara default).
5. Ganti peran lewat chip di atas chat: **Penasihat**, **Etika chat**, **Guru e-book**.

## 6. Guru e-book & Insight

- **Kelola Pengetahuan** > **Impor PDF** > pilih file > isi judul > tunggu progres
  (*Membuat embedding... 12 / 80 potongan*). PDF hasil scan (gambar) tidak bisa dibaca.
- Pilih peran **Guru e-book** lalu tanya isi buku. Sumber (judul + halaman) tampil di bawah
  jawaban.
- **Insight** > tombol **+** untuk menulis catatan pribadi; catatan ikut dipakai Guru e-book
  sebagai sumber "(catatan pribadi)".
- Di setiap jawaban: **Simpan sebagai insight**, atau **Koreksi** > tulis jawaban yang
  benar > simpan.
- Hapus buku/catatan di **Kelola Pengetahuan** (ikon tempat sampah).

## 7. Ganti model

**Pengaturan AI** > pilih **Default (Qwen3 1.7B)** atau **Uncensored (Gemma 4 E2B)**.
Lisku menyimpan pilihan, menulis `~/.lisku-model`, lalu menyalakan ulang server. Jika model
uncensored gagal dimuat, Lisku memberi tahu dan otomatis kembali ke model default.

## 8. Hemat RAM

AI dimatikan otomatis bila Lisku di background, atau halaman AI tidak disentuh lebih dari
**2 menit**. Kirim pesan lagi untuk menyalakannya. Tombol ⏹ di kartu status mematikan AI
saat itu juga.

---

## Troubleshooting

| Pesan / gejala | Penyebab & solusi |
|---|---|
| **Termux belum terinstall** | Pasang Termux (langkah 2), buka sekali, tekan *Coba lagi*. |
| **Izin ... ditolak** | Aktifkan izin di Pengaturan > Aplikasi > Lisku > Izin > Izin tambahan. |
| **allow-external-apps belum aktif** | Jalankan perintah di langkah 2.3 di Termux (tombol *Salin* tersedia di Lisku), lalu *Sudah, coba lagi*. |
| **AI belum di-setup** | Tekan **Setup AI**. |
| **Server AI gagal menyala** | Buka *Detail teknis*. Di Termux cek: `bash ~/start-llm.sh` lalu `tail -n 50 ~/llm-logs/chat.log`. |
| **Model gagal dimuat** | File model rusak/terpotong atau RAM kurang. Tutup aplikasi berat, jalankan **Setup AI** lagi. Untuk mengunduh ulang: `rm ~/models/<file>.gguf` lalu Setup AI. |
| `unknown argument: --reasoning-format` di log | llama-cpp terlalu lama: `pkg upgrade llama-cpp`. |
| Setup berhenti di unduhan | Koneksi terputus. Tekan **Setup AI** lagi (resume). |
| Termux tidak terbuka saat Setup | Buka Termux manual; sesi "Lisku AI Setup" sudah berjalan. Beri izin *Tampilkan di atas aplikasi lain* ke Termux. |
| AI mati sendiri saat layar mati | Set baterai Termux ke *Tidak dibatasi*, nonaktifkan batasan proses turunan (langkah 2.4). |
| Jawaban sangat lambat | Pakai model Default; tutup aplikasi lain. Thinking Qwen3 memang butuh beberapa detik. |
| Guru e-book: "Server embedding belum siap" | Tunggu beberapa detik lalu ulangi; cek `tail ~/llm-logs/embed.log`. |

Perintah manual di Termux:

```bash
bash ~/start-llm.sh                      # nyalakan server chat (8080) + embedding (8081)
bash ~/stop-llm.sh                       # matikan
bash ~/lisku-status.sh                   # status proses + potongan log
curl http://127.0.0.1:8080/health        # {"status":"ok"} jika siap
echo uncensored > ~/.lisku-model         # atau: echo default > ~/.lisku-model
tail -f ~/llm-logs/chat.log              # pantau log chat
ls -lh ~/models                          # file model
```
