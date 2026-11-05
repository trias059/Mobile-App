# Arsitektur Asisten AI Lisku

Asisten AI Lisku berjalan **100% offline di HP yang sama** (target: Asus Zenfone 11 Ultra,
RAM 12 GB). Lisku tidak memuat model sendiri; model dijalankan oleh `llama-server`
(llama.cpp) di **Termux**, dan Lisku berbicara dengannya lewat HTTP lokal.

```
┌──────────────────────── HP Android ────────────────────────┐
│                                                            │
│  Lisku (Flutter)                       Termux              │
│  ┌──────────────────────┐   RUN_COMMAND   ┌──────────────┐ │
│  │ TermuxBridge.kt      │ ──────────────► │ bash -c ...  │ │
│  │ (platform channel)   │ ◄────────────── │ start/stop   │ │
│  └──────────────────────┘  PendingIntent  └──────┬───────┘ │
│  ┌──────────────────────┐                        │ nohup   │
│  │ AiServerController   │    HTTP 127.0.0.1      ▼         │
│  │ LlmService (SSE)     │ ◄──────────────► llama-server    │
│  │ KnowledgeService     │      :8080  chat (Qwen3/Gemma)   │
│  │ (RAG, Hive)          │ ◄──────────────► llama-server    │
│  └──────────────────────┘      :8081  embedding            │
└────────────────────────────────────────────────────────────┘
```

## Server

| Peran      | URL                                     | Flag penting                                        |
|------------|-----------------------------------------|-----------------------------------------------------|
| Chat       | `http://127.0.0.1:8080/v1/chat/completions` | `-c 4096 -t 6 --jinja --reasoning-format deepseek` |
| Embedding  | `http://127.0.0.1:8081/v1/embeddings`   | `--embedding -c 2048 -b 2048 -ub 2048`              |

`--reasoning-format deepseek` membuat llama-server memisahkan isi `<think>` model ke field
`reasoning_content`, dan jawaban ke `content` — juga saat streaming (`delta.reasoning_content`
vs `delta.content`). Lisku tetap punya fallback parser `<think>...</think>` bila server lama
tidak memisahkannya.

Kedua server dijalankan di background dengan `nohup` oleh `~/start-llm.sh`, log ke
`~/llm-logs/chat.log` dan `~/llm-logs/embed.log`, PID ke `~/llm-logs/*.pid`.
`termux-wake-lock` menjaga Termux tetap hidup selama server menyala.

## Model

| Kunci              | Repo Hugging Face                                  | File lokal                         | Kapan diunduh |
|--------------------|----------------------------------------------------|------------------------------------|---------------|
| Chat default       | `ggml-org/Qwen3-1.7B-GGUF:Q4_K_M`                  | `~/models/Qwen3-1.7B-Q4_K_M.gguf`  | Setup AI |
| Embedding          | `ggml-org/embeddinggemma-300M-GGUF:Q8_0`           | nama dari API HF, dicatat di `~/models/embed.path` | Setup AI |
| Chat uncensored    | `TrevorJS/gemma-4-E2B-it-uncensored-GGUF:Q4_K_M` (±3,4 GB) | nama dari API HF, dicatat di `~/models/chat-uncensored.path` | saat pertama kali dipilih di Pengaturan |

- Semua unduhan memakai `wget -c` (resume) ke `~/models` lewat fungsi bersama di
  `lisku-models-lib.sh`. Selama mengunduh ada penanda `<file>.lisku-partial`; file
  dianggap lengkap hanya bila penanda itu sudah hilang.
- **Setup AI hanya mengunduh model default + embedding (±1,5 GB).**
- **Model uncensored** diunduh oleh `download-uncensored.sh` di sesi foreground Termux,
  setelah user memilih "Uncensored" di Pengaturan dan menyetujui dialog (±3,4 GB).
  Baru setelah unduhan lengkap Lisku menulis `~/.lisku-model` dan me-restart server.
  Dibatalkan/gagal → tetap model default.
- `start-llm.sh` memakai `-m <file lokal>`. Untuk default & embedding, bila file lokal
  tidak ada, jatuh ke `-hf <repo:quant>`. Untuk **uncensored tidak ada `-hf`**: bila
  filenya belum lengkap, skrip menulis `default` ke `~/.lisku-model`, menyalakan model
  default, dan mencetak `LISKU_WARN:UNCENSORED_MISSING` sehingga Lisku memberi tahu user.
- Jika `~/models/Qwen3-1.7B-Q4_K_M.gguf` sudah ada, file itu langsung dipakai untuk model default.
- Pilihan model aktif ada di `~/.lisku-model` (`default` | `uncensored`), ditulis Lisku via RUN_COMMAND.

## File di Termux

| File                   | Isi                                                             |
|------------------------|-----------------------------------------------------------------|
| `~/start-llm.sh`       | baca `~/.lisku-model`, pkill instance lama, nyalakan 2 server   |
| `~/stop-llm.sh`        | `pkill llama-server`, lepas wake-lock                           |
| `~/lisku-status.sh`    | laporan `CHAT_ALIVE`, `EMBED_ALIVE`, model, tail log (dibaca app) |
| `~/lisku-models-lib.sh`| fungsi unduh bersama (`download`, `hf_file`, `model_complete`)  |
| `~/download-uncensored.sh` | unduh model uncensored (dijalankan dari Pengaturan AI)      |
| `~/.lisku-model`       | pilihan model aktif                                             |
| `~/models/`            | file `.gguf`                                                    |
| `~/llm-logs/`          | log & PID                                                       |

Sumber semua skrip ada di folder [`termux/`](../termux) dan dibundel sebagai asset Flutter,
jadi skrip di repo **sama persis** dengan yang dikirim aplikasi.

## Integrasi Termux (Fase 1)

- `android/.../TermuxBridge.kt` mengirim intent `com.termux.RUN_COMMAND` ke service
  `com.termux/com.termux.app.RunCommandService` dengan
  `RUN_COMMAND_PATH=/data/data/com.termux/files/usr/bin/bash` dan argumen `-c <skrip>`.
- Hasil (stdout, stderr, exit code, errmsg) dikirim balik Termux lewat `PendingIntent`
  ke `TermuxResultReceiver`, lalu diteruskan ke Dart sebagai hasil `MethodChannel`.
- Izin `com.termux.permission.RUN_COMMAND` diminta saat runtime setelah dialog penjelasan.
- **Setup AI** mengirim satu skrip inline yang berjalan di sesi **foreground** Termux
  (`RUN_COMMAND_BACKGROUND=false`, session action `0`) agar progres terlihat:
  tulis skrip → `pkg install -y llama-cpp wget curl` → buat folder → unduh model → cek.

### Siklus hidup server (`AiServerController`)

1. Halaman AI dibuka (`attachPage`) → cek Termux & izin → jika `/health` belum OK jalankan
   `start-llm.sh` → polling `/health` tiap 1 detik (status "Menyalakan AI..." /
   "Memuat model ke RAM..."), tiap 10 detik cek proses lewat `lisku-status.sh`.
2. Timer idle 2 menit di-reset oleh setiap interaksi (sentuh layar, ketik, kirim,
   streaming, impor). Habis → `stop-llm.sh`. Selama streaming/impor (busy) tidak dimatikan.
3. App ke background → selain timer Dart, Lisku mengirim perintah *delayed stop* ke Termux
   (`sleep 120` lalu stop jika tidak dibatalkan). Ini tetap jalan walau Android membekukan
   Lisku. Saat app kembali ke depan, delayed stop dibatalkan.
4. Mengirim pesan saat server mati → otomatis dinyalakan lagi.

### Error yang dibedakan

| Kondisi                         | Deteksi                                             |
|---------------------------------|-----------------------------------------------------|
| Termux belum terinstall         | `getPackageInfo("com.termux")` gagal               |
| Izin ditolak                    | hasil dialog izin / `SecurityException`            |
| allow-external-apps belum aktif | `errmsg` hasil Termux menyebut `allow-external-apps` |
| Belum setup                     | `start` mengeluarkan `LISKU_ERR:NOT_SETUP/NO_LLAMA` |
| Server gagal menyala            | proses mati / `/health` timeout                    |
| Model gagal dimuat              | log berisi `error loading model` dll. Jika model uncensored → otomatis kembali ke default + notifikasi |

## Chat (Fase 2)

- `lib/services/llm_service.dart` → `POST /v1/chat/completions` dengan `stream: true`.
  `SseParser` memecah aliran byte jadi event `data:`; tiap delta dipisah jadi
  `reasoning` dan `content`.
- UI: selama hanya `reasoning` yang datang → animasi **Thinking...** tanpa teks pikiran.
  Saat `content` datang → jawaban muncul per kata. Reasoning disimpan per pesan dan bisa
  dibuka lewat tombol "Lihat proses berpikir".
- Tiga peran (system prompt bahasa Indonesia): Penasihat, Etika chat, Guru e-book.
- **Batas `max_tokens` per peran** (`AiPersona.maxTokens`): peran dengan thinking
  (Penasihat, Guru e-book) 1500 token; tanpa thinking (Etika chat) 600 token. Etika chat
  mengirim `chat_template_kwargs: {"enable_thinking": false}` agar Qwen3 langsung menjawab.
- `finish_reason: "length"` disimpan di pesan (`stopReason`). Jika sudah ada jawaban →
  catatan "Jawaban terpotong. Coba tanya lebih spesifik." Jika batas habis saat masih
  berpikir (belum ada `content`) → loading "Thinking..." berhenti dan tampil "Model berpikir
  terlalu lama. Coba ulangi atau sederhanakan pertanyaan."; "Lihat proses berpikir" tetap ada.
- Riwayat disimpan di Hive box `ai_chat_messages` (`AiChatMessage`, typeId 50).

## RAG e-book & insight (Fase 3)

- Impor PDF (`syncfusion_flutter_pdf`, di isolate) → teks per halaman → potongan ±500 kata
  dengan overlap ±50 (`TextChunker`), menyimpan judul buku dan rentang halaman.
- Tiap potongan di-embed lewat port 8081 (prefix dokumen EmbeddingGemma
  `title: ... | text: ...`), disimpan di Hive box `ai_knowledge_chunks`
  (`KnowledgeChunk`, typeId 51) beserta vektor. Sumber di `ai_knowledge_sources`
  (`KnowledgeSource`, typeId 52).
- Guru e-book: embed pertanyaan (prefix `task: search result | query:`), ambil 3 potongan
  dengan cosine similarity tertinggi, sisipkan sebagai konteks bernomor, minta model
  menjawab hanya dari konteks dan menyebut sumber. Sumber ditampilkan di bawah jawaban.
- Insight: catatan pribadi di-embed ke indeks yang sama dengan tipe `note`
  (ditampilkan sebagai "catatan pribadi"). Tiap jawaban AI punya tombol
  "Simpan sebagai insight" dan kolom koreksi (koreksi disimpan sebagai insight).
- Kelola Pengetahuan: daftar buku & catatan, hapus (beserta semua potongannya).
