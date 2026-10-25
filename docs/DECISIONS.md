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
21. **Ekstraksi PDF: `syncfusion_flutter_pdf`** (pure Dart, jalan di isolate lewat `compute`,
    tidak butuh binary native). Lisensinya Syncfusion Community License — gratis untuk
    individu/usaha kecil; jika tidak cocok, cukup ganti `pdf_text_extractor.dart`.
    PDF hasil scan (tanpa teks) ditolak dengan pesan yang jelas (tidak ada OCR).
22. **Chunking lintas halaman.** Kata dari semua halaman digabung, dipotong 500 kata
    (overlap 50); tiap potongan menyimpan halaman awal & akhir ("hal. 12–13"). Sisa ekor
    < 50 kata digabung ke potongan sebelumnya agar tidak ada potongan kecil tak berguna.
23. **Prefix EmbeddingGemma**: dokumen `title: <judul> | text: <isi>`, pertanyaan
    `task: search result | query: <pertanyaan>` (format yang direkomendasikan model).
24. **Embedding satu potongan per request** agar progres impor akurat dan satu potongan
    selalu muat di ubatch 2048. Bila gagal di tengah, potongan yang sudah tersimpan
    di-rollback sehingga tidak ada buku setengah jadi. Impor bisa dibatalkan.
25. **Guru e-book tidak mengirim riwayat chat** ke model; 3 potongan × ±500 kata sudah
    memakai sebagian besar konteks 4096 token.
26. **Indeks gabungan.** Catatan pribadi/insight disimpan di box yang sama dengan potongan
    buku (`sourceType: note`), jadi pencarian top-3 mencakup keduanya; labelnya
    "(catatan pribadi)".
27. **Koreksi jawaban** disimpan sebagai insight berjudul "Koreksi: <pertanyaan>", sehingga
    di pertanyaan berikutnya Guru e-book bisa mengambil koreksi tersebut sebagai konteks.
    Kolom koreksi muncul setelah menekan tombol "Koreksi" agar bubble tetap ringkas.
28. **Vektor disimpan sebagai `List<double>` di Hive** dan dicari secara linear di memori.
    Cukup cepat untuk ribuan potongan di HP; tidak perlu vector DB.
