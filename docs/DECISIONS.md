# Catatan Keputusan (Asisten AI)

Keputusan yang diambil saat implementasi tanpa konfirmasi, beserta alasannya.

1. **Titik masuk AI.** `main.dart` memakai `HomeScreen` (bottom nav). Tab baru **AI**
   ditambahkan di sana, dan menu cepat "Asisten AI" juga ditambahkan di `HomeContent`
   (`pages/home_page.dart`). Halaman yang sudah ada tidak diubah perilakunya.
2. **State management.** Mengikuti pola yang ada: `provider` + `ChangeNotifier`.
   `AiServerController` didaftarkan di `MultiProvider` bersama `TaskProvider`.
3. **Unduhan model memakai `wget -c` ke `~/models`**, bukan hanya `-hf`, agar bisa
   di-resume, tidak butuh internet saat start (tanpa cek ulang ke HF), dan lokasi file
   jelas. Nama file dicari via API Hugging Face saat setup. `start-llm.sh` tetap jatuh
   ke `-hf repo:quant` bila file lokal tidak ada, jadi perilaku "unduh otomatis ke cache"
   tetap tersedia.
4. **Skrip Termux dibundel sebagai asset** (`termux/` di `pubspec.yaml`) dan dirangkai
   jadi satu skrip inline saat Setup AI. Satu sumber kebenaran untuk repo dan aplikasi.
5. **Skrip status tambahan `~/lisku-status.sh`** untuk membaca apakah proses hidup dan
   tail log, agar error "server gagal" vs "model gagal dimuat" bisa dibedakan.
6. **Hasil RUN_COMMAND lewat PendingIntent** ke `TermuxResultReceiver`. Dari sinilah
   error `allow-external-apps` terdeteksi. Jika Termux tidak membalas (timeout), Lisku
   tetap lanjut polling `/health`.
7. **Arti "tidak dipakai > 2 menit".** Timer idle 2 menit di-reset oleh interaksi apa pun
   di halaman AI (sentuh, ketik, kirim) dan tidak berjalan selama streaming/impor. Jadi
   AI juga mati bila halaman AI terbuka tapi didiamkan 2 menit; pesan berikutnya akan
   menyalakannya lagi otomatis.
8. **Delayed stop di sisi Termux** saat app ke background, karena timer Dart tidak
   dijamin jalan ketika Android membekukan proses aplikasi.
9. **`termux-wake-lock`** dipanggil di start dan dilepas di stop agar Android tidak
   membunuh llama-server saat layar mati.
10. **`--jinja`** ditambahkan ke server chat agar template chat & pemisahan reasoning
    bekerja juga di build llama.cpp yang belum mengaktifkannya secara default.
11. **Embedding server**: `-c 2048 -b 2048 -ub 2048 -t 2` (EmbeddingGemma maks 2048 token;
    satu potongan harus muat dalam satu ubatch). Thread chat tetap `-t 6` sesuai spesifikasi.
12. **Test bawaan `test/widget_test.dart` dihapus.** Itu template "counter" Flutter yang
    tidak pernah cocok dengan aplikasi ini (gagal kompilasi). Diganti unit test AI.
13. **`lib/task_system_complete.dart` dikecualikan dari analyzer.** File referensi lama yang
    tidak di-import di mana pun dan `part`-nya tidak ada; file tidak diubah/dihapus.
14. **Chat: riwayat yang dikirim ke model** dibatasi 6 pesan / ±4000 karakter terakhir
    per peran, karena konteks server hanya 4096 token (thinking juga memakai token).
15. **Riwayat chat per peran.** Tiap peran (Penasihat, Etika chat, Guru e-book) punya
    riwayat sendiri di box `ai_chat_messages`; bisa dihapus per peran dari menu ⋮.
16. **Jawaban per kata** dianimasikan di UI (±35 ms per kata, mempercepat diri bila
    tertinggal dari model), sementara jawaban lengkap langsung disimpan ke Hive.
17. **Tombol Stop** membatalkan stream; jawaban parsial disimpan dengan akhiran "…".
18. **Format teks** hanya mendukung `**tebal**` (tanpa paket markdown tambahan) agar
    dependensi minimal.
19. **Sampling chat**: temperature 0.6, top_p 0.95, top_k 20 (rekomendasi Qwen3 mode berpikir).
20. **Hive typeId baru**: 50 (`AiChatMessage`), 51 (`KnowledgeChunk`), 52 (`KnowledgeSource`) —
    jauh dari typeId yang sudah dipakai (0–26).
