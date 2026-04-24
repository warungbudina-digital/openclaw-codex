# Panduan Instalasi & Pengujian (OpenClaw + Codex CLI, Single Container)

Panduan ini untuk setup file yang ada di repo ini:

- `Dockerfile`
- `openclaw.json`

Tujuan: menjalankan OpenClaw Gateway dengan model default `codex-cli/gpt-5.4` dalam **satu container**.

## 1) Prasyarat

Di host kamu, pastikan ada:

1. Docker aktif (`docker --version` berhasil).
2. Akses internet untuk pull image + install package saat build.
3. Kredensial Codex CLI tersedia di host pada path:
   - `~/.codex/auth.json`

> Penting: tanpa `~/.codex/auth.json` (atau auth setara), backend `codex` tidak bisa dipakai untuk inferensi.

Cek cepat di host sebelum `docker run`:

```bash
ls -lah ~/.codex/auth.json
```

## 2) Struktur file minimal

- `Dockerfile` meng-install:
  - `openclaw@latest`
  - `@openai/codex@latest`
- `openclaw.json` mengatur:
  - `gateway.mode = local`
  - `gateway.bind = lan`
  - auth token gateway
  - model default `codex-cli/gpt-5.4`
  - backend `codex-cli.command = "codex"`

## 3) Build image

Jalankan dari folder repo ini:

```bash
docker build --no-cache -t openclaw-codex:local .
```

## 4) Jalankan container

Perintah berikut me-mount state OpenClaw dan kredensial Codex dari host:

```bash
docker run --rm -it \
  -p 18789:18789 \
  -v "$HOME/.codex:/root/.codex" \
  -v openclaw_state:/data/openclaw \
  --name openclaw-codex \
  openclaw-codex:local
```

Opsional (direkomendasikan): override token saat runtime supaya tidak pakai token default:

```bash
docker run --rm -it \
  -p 18789:18789 \
  -e OPENCLAW_GATEWAY_TOKEN="ganti-dengan-token-kamu" \
  -v "$HOME/.codex:/root/.codex" \
  -v openclaw_state:/data/openclaw \
  --name openclaw-codex \
  openclaw-codex:local
```

Jika berhasil, gateway akan listen di port `18789` dengan mode `bind: "lan"`.

## 5) Pengujian dasar (smoke test)

Buka terminal baru di host.

### A. Cek gateway hidup

```bash
curl -i http://127.0.0.1:18789/health || true
```

### B. Cek status model dari dalam container

```bash
docker exec -it openclaw-codex openclaw models status
```

### C. Kirim pesan uji (pakai model default dari config)

```bash
docker exec -it openclaw-codex openclaw agent --message "Balas: OK"
```

Karena `openclaw.json` sudah set default ke `codex-cli/gpt-5.4`, perintah ini cukup untuk smoke test.

Ekspektasi: ada respons teks dari agent, bukan error auth/command-not-found.

Jika command agent gagal karena auth/model, jalankan cek berikut:

```bash
docker exec -it openclaw-codex ls -lah /root/.codex/auth.json
docker exec -it openclaw-codex codex --version
docker exec -it openclaw-codex openclaw models status
```

## 6) Troubleshooting cepat

### Masalah: `error: unknown option --config`

Image lama masih memakai `CMD ... --config ...`. Solusinya rebuild image:

```bash
docker build --no-cache -t openclaw-codex:local .
```

Pada versi ini config dibaca dari env `OPENCLAW_CONFIG_PATH=/app/openclaw.json`, bukan flag `--config`.

### Masalah: `Invalid --bind`

Gunakan nilai bind yang valid saja: `loopback`, `lan`, `tailnet`, `auto`, atau `custom`.
Di setup ini bind diatur lewat config menjadi `"lan"`, jadi **jangan** menambahkan `--bind 0.0.0.0` manual.

### Masalah: command debug digabung jadi satu baris (`--help\ndocker ...`)

Jalankan perintah debug **terpisah** (masing-masing satu command):

```bash
docker exec -it openclaw-codex openclaw agent --help
docker exec -it openclaw-codex openclaw --version
```

Atau pakai pemisah command eksplisit:

```bash
docker exec -it openclaw-codex openclaw agent --help ; docker exec -it openclaw-codex openclaw --version
```

Jika terminal mengirim literal `\n` (bukan newline), hapus `\n` dan ketik Enter normal.

### Masalah: `error: unknown option --model`

Gunakan perintah tanpa override model dulu (mengandalkan default di config):

```bash
docker exec -it openclaw-codex openclaw agent --message "Balas: OK"
```

Pada OpenClaw versi di container ini (`2026.4.21`), output `openclaw agent --help` memang **tidak** menampilkan opsi `--model`, jadi ini normal.

Model mengikuti default dari config (`openclaw.json`) atau sesi yang sudah ada.

```bash
docker exec -it openclaw-codex openclaw agent --help
docker exec -it openclaw-codex openclaw --version
```

### Masalah: `codex: command not found`

- Verifikasi image benar-benar dibuild dari `Dockerfile` ini.
- Cek di container:

```bash
docker exec -it openclaw-codex which codex
```

### Masalah: `/root/.codex/auth.json` tidak ditemukan di container

Ini berarti folder host `~/.codex` berhasil ter-mount, tapi file `auth.json` memang belum ada di host.

1. Login Codex CLI di **host** dulu sampai file auth terbentuk:

```bash
codex login
ls -lah ~/.codex/auth.json
```

2. Stop container lama lalu jalankan ulang dengan mount yang sama:

```bash
docker stop openclaw-codex

docker run --rm -it \
  -p 18789:18789 \
  -v "$HOME/.codex:/root/.codex" \
  -v openclaw_state:/data/openclaw \
  --name openclaw-codex \
  openclaw-codex:local
```

3. Verifikasi lagi di container:

```bash
docker exec -it openclaw-codex ls -lah /root/.codex/auth.json
```

### Masalah: auth gagal / unauthorized

- Pastikan file host ada:

```bash
ls -lah ~/.codex/auth.json
```

- Pastikan mount benar:

```bash
docker exec -it openclaw-codex ls -lah /root/.codex/auth.json
```

### Masalah: healthcheck container jadi `unhealthy`

- Lihat log container:

```bash
docker logs openclaw-codex --tail 200
```

- Jalankan manual check di container:

```bash
docker exec -it openclaw-codex openclaw models status
```

## 7) Stop dan bersihkan

```bash
docker stop openclaw-codex
```

Volume `openclaw_state` tetap tersimpan agar state gateway persisten.


## 8) Alternatif jika `~/.codex/auth.json` tidak bisa dibuat di VPS

Kalau login Codex CLI di cloud shell/VPS gagal, ada 2 opsi praktis:

### Opsi A (paling stabil untuk server): pakai OpenAI API key

Repo ini sudah disiapkan file alternatif `openclaw.apikey.json` dengan model default `openai/gpt-5.4`.

Jalankan container dengan config alternatif + env API key:

```bash
docker run --rm -it \
  -p 18789:18789 \
  -e OPENAI_API_KEY="isi_api_key_kamu" \
  -e OPENCLAW_CONFIG_PATH="/app/openclaw.apikey.json" \
  -v openclaw_state:/data/openclaw \
  --name openclaw-codex \
  openclaw-codex:local
```

Lalu uji:

```bash
docker exec -it openclaw-codex openclaw models status
docker exec -it openclaw-codex openclaw agent --message "Balas: OK"
```

### Opsi B: login Codex di laptop lokal lalu copy `auth.json` ke VPS

#### 1) Login Codex di laptop

Di laptop (macOS/Linux):

```bash
codex login
```

Verifikasi file auth sudah ada:

```bash
ls -lah ~/.codex/auth.json
```

#### 2) Copy file ke VPS

Di laptop, kirim file auth ke VPS (ganti `user@vps`):

```bash
ssh user@vps 'mkdir -p ~/.codex && chmod 700 ~/.codex'
scp ~/.codex/auth.json user@vps:~/.codex/auth.json
ssh user@vps 'chmod 600 ~/.codex/auth.json && ls -lah ~/.codex/auth.json'
```

#### 3) Verifikasi dari VPS + container

Di VPS, pastikan file host ada:

```bash
ls -lah ~/.codex/auth.json
```

Lalu jalankan ulang container dengan mount yang sama:

```bash
docker run --rm -it \
  -p 18789:18789 \
  -v "$HOME/.codex:/root/.codex" \
  -v openclaw_state:/data/openclaw \
  --name openclaw-codex \
  openclaw-codex:local
```

Di terminal baru, verifikasi file masuk ke container:

```bash
docker exec -it openclaw-codex ls -lah /root/.codex/auth.json
```

#### Catatan Windows (PowerShell)

Jika login dilakukan di Windows, biasanya file ada di:

```powershell
$env:USERPROFILE\.codex\auth.json
```

Contoh copy dari PowerShell (OpenSSH):

```powershell
scp $env:USERPROFILE\.codex\auth.json user@vps:~/.codex/auth.json
```

## 9) FAQ singkat

### Apakah harus install Codex CLI di laptop lokal dulu sebelum `codex login`?

**Ya, benar.** Command `codex login` hanya ada jika Codex CLI sudah terpasang di laptop lokal.

Untuk Windows, disarankan jalankan lewat WSL2.

Contoh instalasi (macOS/Linux/WSL):

```bash
npm install -g @openai/codex@latest
codex --version
codex login
```

Jika kamu tidak ingin memasang Codex CLI lokal, gunakan jalur alternatif **API key** (lihat Opsi A di bagian 8).

## 10) Pemahaman OAuth vs API key vs `~/.codex/auth.json`

Pertanyaan ini penting karena istilahnya mirip.

### A. OAuth OpenAI di OpenClaw Onboard

Saat Onboard menampilkan pilihan provider OpenAI dengan opsi **OAuth** atau **API key**, itu adalah mekanisme auth di sisi **OpenClaw provider config**:

- **OAuth**: token dikelola oleh OpenClaw (profil auth OpenClaw).
- **API key**: kamu isi `OPENAI_API_KEY` / auth profile API key.

### B. `~/.codex/auth.json` (Codex CLI)

`~/.codex/auth.json` adalah kredensial milik **Codex CLI** (hasil `codex login`).
Ini dipakai saat model yang kamu jalankan adalah jalur **`codex-cli/...`**.

### C. Jadi, apakah OAuth OpenAI = `auth.json` Codex?

**Tidak sama persis.**

- OAuth OpenAI di Onboard = auth di layer OpenClaw provider.
- `~/.codex/auth.json` = auth di layer binary Codex CLI.

Keduanya bisa sama-sama terhubung ke akun OpenAI kamu, tetapi **storage dan runtime path-nya berbeda**.

### D. Dampak ke project testing ini

- Jika pakai `openclaw.json` (default model `codex-cli/gpt-5.4`), maka kamu butuh binary `codex` + `~/.codex/auth.json` di container.
- Jika pakai `openclaw.apikey.json` (default model `openai/gpt-5.4`), maka cukup `OPENAI_API_KEY` tanpa `~/.codex/auth.json`.

## 11) Menjalankan OpenClaw + Chromium via `docker-compose` (background)

File `docker-compose.yml` sudah menggabungkan 2 service:

- `openclaw-codex` (port `18789`)
- `chromium-node` (port `3040`)

### A. Siapkan token gateway (opsional, direkomendasikan)

```bash
export OPENCLAW_GATEWAY_TOKEN="ganti-dengan-token-kamu"
```

### B. Jalankan di background

```bash
docker compose up -d
```

### C. Cek status

```bash
docker compose ps
docker compose logs -f openclaw-codex
docker compose logs -f chromium-node
```

### D. Stop semua service

```bash
docker compose down
```

### E. Catatan

- Build image OpenClaw dulu sebelum `compose up`:

```bash
docker build --no-cache -t openclaw-codex:local .
```

- Data Chromium dipersist ke `${HOME}/chromium-data`.
- Kredensial Codex CLI dibaca dari `${HOME}/.codex`.

## 12) Authorize Codex CLI di VPS/headless (kasus error #7)

Dari log kamu, `codex login` sudah benar dan server callback lokal jalan di `localhost:1455`.

### Rekomendasi utama (paling mudah): pakai device auth

Di container OpenClaw:

```bash
docker exec -it openclaw-codex codex login --device-auth
```

Flow ini tidak butuh callback browser ke `localhost:1455`, jadi paling cocok untuk cloud shell/VPS.

### Alternatif browser callback via port 1455

`docker-compose.yml` sudah dibuka juga port `1455:1455` untuk OpenClaw service.

Langkah umum:

1. Jalankan `codex login` di container.
2. Ambil URL authorize dari output.
3. Buka URL itu di browser lokal kamu.
4. Pastikan callback `http://localhost:1455/auth/callback` bisa mencapai container (via port forwarding host/server).

### Tentang Chromium container port 3040

- Chromium di `3040` bisa dipakai untuk membuka halaman auth.
- Tetapi callback login Codex tetap mengarah ke `localhost:1455` (server login milik proses `codex login`).
- Jadi **port 3040 bukan pengganti callback 1455**; yang wajib reachable tetap endpoint `1455`.

### Verifikasi hasil login

Setelah login sukses:

```bash
docker exec -it openclaw-codex ls -lah /root/.codex/auth.json
```

### Keamanan: jangan share URL callback OAuth

URL seperti ini:

`http://localhost:1455/auth/callback?code=...&state=...`

**bukan** isi `auth.json`, melainkan URL callback yang membawa kode OAuth sementara.

- Jangan diposting ke chat/public issue.
- Jika sudah terlanjur terbuka, ulangi login (`codex login --device-auth`) untuk mendapat sesi baru.
- Verifikasi file yang benar dengan:

```bash
docker exec -it openclaw-codex ls -lah /root/.codex/auth.json
```

## 13) Jika Cloud Shell memblokir device-auth (`error sending request ...deviceauth/usercode`)

Kalau environment Cloud Shell gratis memblokir request ke endpoint auth OpenAI (seperti error kamu), langkah paling tepat:

### Opsi 1 (disarankan): lanjut testing pakai API key

Jalankan stack dengan config API key tanpa flow `codex login`:

```bash
export OPENAI_API_KEY="isi_api_key_kamu"
export OPENCLAW_CONFIG_PATH="/app/openclaw.apikey.json"
docker compose up -d
```

Verifikasi:

```bash
docker compose exec openclaw-codex openclaw models status
docker compose exec openclaw-codex openclaw agent --message "Balas: OK"
```

### Opsi 2: login Codex di mesin lain, lalu copy `auth.json`

Jika Cloud Shell tidak bisa auth langsung:

1. Jalankan `codex login` / `codex login --device-auth` di laptop/VM lain yang unrestricted.
2. Copy `~/.codex/auth.json` ke Cloud Shell (`scp`).
3. Restart container supaya mount `/root/.codex` membaca file baru.

### Opsi 3: pindah ke VM dengan egress bebas

Untuk testing penuh OAuth/device-auth di server, gunakan VM/VPS yang tidak memblokir domain auth OpenAI.

### Kenapa ini terjadi?

Masalah ini bukan pada Docker/OpenClaw config, tapi pada kebijakan network egress/proxy environment Cloud Shell.

## 14) Error `npm EACCES` saat install Codex CLI di dalam container

Ya, **mungkin** install Codex CLI di container yang sudah running, tapi error `EACCES` terjadi karena user aktif tidak punya izin tulis ke global npm path (`/usr/local/lib/node_modules`).

### Kenapa bisa terjadi?

- Install global `npm -g` butuh akses tulis direktori sistem.
- Container runtime kamu kemungkinan jalan sebagai user non-root (`node`).

### Opsi perbaikan

#### Opsi A (direkomendasikan): rebuild image dari Dockerfile

Dockerfile project ini sudah meng-install `@openai/codex` saat build, jadi cara paling bersih:

```bash
docker build --no-cache -t openclaw-codex:local .
docker compose up -d --force-recreate
```

#### Opsi B: install di container sebagai root (quick fix)

```bash
docker exec -u 0 -it openclaw-codex sh -lc 'npm install -g @openai/codex@latest'
docker exec -it openclaw-codex codex --version
```

> Catatan: perubahan ini hanya hidup selama lifecycle container/image saat ini.

#### Opsi C: install per-user tanpa root (tanpa sentuh `/usr/local`)

```bash
docker exec -it openclaw-codex sh -lc 'npm config set prefix ~/.local && npm install -g @openai/codex@latest && export PATH="$HOME/.local/bin:$PATH" && codex --version'
```

### Verifikasi cepat

```bash
docker exec -it openclaw-codex which codex
docker exec -it openclaw-codex codex --version
```
