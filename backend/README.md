# Radar Keliling — Backend API (Laravel 12 + PostGIS + Reverb + FCM)

Backend REST API dan Real-Time Geospatial Server untuk **Radar Keliling**, menghubungkan **Pembeli (`buyer`)**, **Pedagang Keliling (`merchant`)**, dan **Administrator (`admin`)** secara *real-time* menggunakan PostgreSQL + **PostGIS**, **Laravel Reverb (WebSocket)**, serta **Firebase Cloud Messaging (FCM)**.

---

## Fitur Utama

1. **Autentikasi & Role-Based Access Control (Sanctum)**:
   - Role: `buyer`, `merchant`, `admin`.
   - Verifikasi email dengan token OTP SHA-256 (kedaluwarsa 60 menit, *rate limit* resend 3x/jam).
   - Manajemen akun (`GET /api/v1/auth/me`, `DELETE /api/v1/account`).
2. **Real-Time Spatial Radar (PostGIS + Geohash Grid)**:
   - Pencarian pedagang keliling aktif dalam radius hingga **3.000 meter** menggunakan `ST_DWithin` dan `ST_Distance` berbasis indeks spasial `GIST`.
   - *Threshold* pergerakan GPS **5 meter** (`has_moved_5m`) untuk efisiensi broadcast WebSocket pada channel `private-radar.{geohash}`.
3. **Sistem Panggilan Pedagang ("Panggil Pedagang")**:
   - Validasi akurasi GPS (`<= 50m`), status jualan pedagang (`is_selling = true`), kesegaran lokasi (`<= 30 detik`), jarak panggilan (`<= 200m`), dan *rate-limit* (`maks 2 panggilan / 60 detik`).
   - Manajemen & *sorting* pesanan untuk pedagang (`?sort=priority|nearest|latest|oldest|status` & `?status=pending,accepted`).
   - Privasi lokasi pembeli: koordinat pembeli otomatis kedaluwarsa dan dihapus fisik dari database setelah **15 menit** melalui scheduler `php artisan radar:cleanup`.
4. **Ulasan Buta (*Blind Review*) & Moderasi Admin**:
   - Pembeli dapat memberi rating `1–5` bintang setelah panggilan `accepted` atau `completed`.
   - Pelaporan ulasan oleh komunitas dan moderasi `hide`/`unhide` oleh Admin.
5. **Predictive Demand Heatmap (Spatial AI Clustering)**:
   - Klasterisasi titik permintaan pembeli per jam (`0–23`) dan kategori menggunakan `ST_SnapToGrid` & `ST_Centroid`.
   - Rekomendasi *hotspot* terdekat untuk pedagang (`GET /api/v1/merchant/radar/buyer-hotspots`).
6. **Swagger / OpenAPI 3.1 Interactive Docs**:
   - Tersedia di `/docs` (otomatis tersembunyi/`404` ketika `APP_ENV=production`).

---

## Akun Bawaan Database Seeder

Jalankan `php artisan migrate --seed` untuk mengisi data awal (5 pedagang keliling di Surabaya, katalog menu, riwayat panggilan, ulasan, dan ~475 titik *Demand Heatmap*):

| Role | Email | Password | Keterangan |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin@radarkeliling.com` | `password` | Moderasi laporan & ulasan |
| **Buyer 1** | `buyer@radarkeliling.com` | `password` | Akun pembeli utama |
| **Buyer 2** | `andi@radarkeliling.com` | `password` | Akun pembeli kedua |
| **Merchant 1** | `budi@radarkeliling.com` | `password` | Bakso Malang Cak Budi (`is_selling = true`) |
| **Merchant 2** | `siti@radarkeliling.com` | `password` | Siomay & Batagor Bu Siti (`is_selling = true`) |
| **Merchant 3** | `joko@radarkeliling.com` | `password` | Es Cendol Dawet Mas Joko (`is_selling = true`) |
| **Merchant 4** | `eneng@radarkeliling.com` | `password` | Cilok & Cireng Crispy Teh Eneng (`is_selling = true`) |
| **Merchant 5** | `ali@radarkeliling.com` | `password` | Martabak & Terang Bulan Bang Ali (`is_selling = false`) |

---

## Instalasi & Menjalankan Lokal

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate

# Pastikan PostgreSQL dengan ekstensi PostGIS aktif, lalu jalankan migrasi & seeder:
php artisan migrate --seed

# Buat symlink public storage untuk foto profil & menu:
php artisan storage:link

# Jalankan server API & WebSocket Reverb:
php artisan serve
php artisan reverb:start
```

---

## Pengujian Otomatis (PHPUnit)

Seluruh fitur dilengkapi **100 test otomatis** (*Unit* & *Feature Tests*):

```bash
cd backend
php artisan test
```
