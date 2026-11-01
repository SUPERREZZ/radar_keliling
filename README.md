# 📡 Radar Keliling

> **Platform Real-Time Hyperlocal Geospatial Penghubung Pedagang Keliling (UMKM) & Pembeli**  
> Dibangun dengan PostgreSQL PostGIS, Laravel Reverb (WebSocket), Flutter, dan OpenStreetMap.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Laravel](https://img.shields.io/badge/Laravel-12.x-FF2D20?logo=laravel&logoColor=white)](https://laravel.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%2B-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![PostGIS](https://img.shields.io/badge/PostGIS-3.4-336791?logo=postgis&logoColor=white)](https://postgis.net)
[![WebSocket](https://img.shields.io/badge/WebSocket-Laravel%20Reverb-yellow?logo=socketdotio&logoColor=white)](https://reverb.laravel.com)
[![FCM](https://img.shields.io/badge/FCM-HTTP%20v1%20API-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🎯 Latar Belakang & Masalah

Pedagang keliling tradisional (seperti bakso, siomay, es dawet, roti keliling, dan sayur gerobak) adalah tulang punggung ekonomi mikro di Indonesia. Namun, mereka menghadapi masalah mendasar:
1. **Ketidakpastian Lokasi**: Pembeli tidak tahu kapan dan lewat mana pedagang sedang melintas di sekitar perumahan/gang mereka.
2. **Keterbatasan Suara Tradisional**: Teriakan atau bunyi lonceng/klakson khas sering kali tidak terdengar dari dalam rumah, terutama di lingkungan tertutup atau ber-AC.
3. **Biaya Platform Mahal**: Aplikasi pesan-antar makanan komersial membebankan komisi tinggi (20%–30%) serta tarif flat Google Maps API yang mencekik bagi pedagang kecil.

**Radar Keliling** hadir sebagai solusi *zero-commission, open-source-first*: platform geospatial real-time yang memungkinkan pembeli mendeteksi gerobak pedagang di sekitarnya dalam radius meteran nyata, memanggil mereka langsung dengan satu sentuhan, dan memandu pedagang menghampiri pembeli melalui navigasi belokan demi belokan (*turn-by-turn*).

---

## ✨ Fitur Utama

### 🛒 Untuk Pembeli (*Buyer*)
- **Radar Spasial Real-Time**: Deteksi pedagang aktif dalam radius 300 m hingga 3.000 m berbasis kalkulasi PostGIS `ST_DWithin` & indeks spasial GIST.
- **Fitur "Panggil Pedagang"**: Panggil pedagang dalam radius aman (maksimal 200 meter) dengan opsional berbagi koordinat GPS instan.
- **Privasi Lokasi Terjamin**: Koordinat pembeli dilindungi kedaluwarsa 15 menit dan dihapus permanen secara otomatis dari database (`radar:cleanup`).
- **Blind Review & Rating**: Berikan rating (1–5 bintang) dan ulasan anonim setelah transaksi selesai untuk membangun reputasi pedagang.

### 🛵 Untuk Pedagang (*Merchant*)
- **Toggle Jualan & Heartbeat GPS**: Cukup nyalakan toggle "Mulai Jualan" saat keliling; koordinat diperbarui secara otomatis dan disiarkan ke pembeli.
- **Notifikasi Panggilan Masuk Real-Time**: Pop-up instan via Laravel Reverb WebSocket yang didukung *fallback* Google Firebase Cloud Messaging (FCM v1) berprioritas tinggi.
- **Navigasi Jalan Raya (Turn-by-Turn)**: Terintegrasi langsung dengan OSRM (*Open Source Routing Machine*) untuk rute belokan jalan nyata menuju pembeli tanpa Google Maps API berbayar.
- **Peta Hotspot & Predictive Demand**: Analisis klaster spasial titik keramaian pembeli berbasis jam (`0–23`) menggunakan algoritma PostGIS `ST_SnapToGrid` & `ST_Centroid`.

### 🛡️ Untuk Administrator (*Admin*)
- **Moderasi Ulasan Komunitas**: Tinjau laporan ulasan tidak pantas dan sembunyikan/tampilkan ulasan (`hide`/`unhide`).
- **Monitoring Ekosistem**: Pemantauan data transaksi, performa merchant, dan kesehatan sistem.

---

## 🏗️ Arsitektur & Tech Stack

```text
               ┌─────────────────────────────────────────┐
               │             FLUTTER MOBILE APP          │
               │  (Riverpod + flutter_map + Geolocator)  │
               └───────▲─────────────────────────▲───────┘
                       │                         │
             REST API  │                         │ WebSocket & Push
         (HTTPS/Bearer)│                         │ (Reverb & FCM v1)
                       ▼                         ▼
               ┌─────────────────────────────────────────┐
               │            NGINX REVERSE PROXY          │
               │      Port 80 (API & WS /app proxy)      │
               └───────▲─────────────────────────▲───────┘
                       │                         │
       FastCGI/PHP 8.2 │                         │ Reverse Proxy (:8080)
                       ▼                         ▼
           ┌───────────────────────────────┐ ┌───────────────────────────┐
           │       LARAVEL 12 BACKEND      │ │    LARAVEL REVERB SERVER  │
           │  - Sanctum Auth               │ │    - Realtime Broadcast   │
           │  - Native FCM v1 Signer (JWT) │ │    - Geohash Private Ch   │
           │  - Geospatial Query Service   │ └───────────────────────────┘
           └───────────────┬───────────────┘
                           │
                   SQL with Spatial Extensions
                           ▼
           ┌───────────────────────────────┐
           │     POSTGRESQL 16 + POSTGIS   │
           │  - GIST Spatial Indexing      │
           │  - ST_DWithin & ST_Distance   │
           │  - ST_SnapToGrid Clustering   │
           └───────────────────────────────┘
