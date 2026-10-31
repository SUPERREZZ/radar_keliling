# 📱 Radar Keliling — Frontend (Flutter)

Bagian ini adalah aplikasi mobile Flutter untuk proyek **Radar Keliling**, dikerjakan oleh tim frontend di branch `mobile`.

---

## 📋 Daftar Isi

- [Tech Stack](#tech-stack)
- [Struktur Folder](#struktur-folder)
- [Branch & Workflow Git](#branch--workflow-git)
- [Konvensi Commit](#konvensi-commit)
- [Setup & Menjalankan Proyek](#setup--menjalankan-proyek)
- [Konfigurasi Environment](#konfigurasi-environment)
- [Fitur & Screen Mapping](#fitur--screen-mapping)
- [Kontrak API — Referensi untuk Flutter](#kontrak-api--referensi-untuk-flutter)
- [Kontrak WebSocket / Real-time](#kontrak-websocket--real-time)
- [Kontrak Model Data (Dart Class Reference)](#kontrak-model-data-dart-class-reference)
- [Aturan Bisnis yang Harus Diterapkan di FE](#aturan-bisnis-yang-harus-diterapkan-di-fe)
- [State Management & Arsitektur](#state-management--arsitektur)
- [Panduan Upload Foto](#panduan-upload-foto)
- [Catatan Penting](#catatan-penting)

---

## Tech Stack

| Kebutuhan | Package / Tool |
|---|---|
| Framework | Flutter (Dart) |
| Peta | `flutter_map` + OpenStreetMap (tile) |
| HTTP Client | `dio` atau `http` |
| WebSocket | `laravel_echo` / `pusher_client` (untuk Reverb) |
| Secure Storage | `flutter_secure_storage` |
| Push Notification | `firebase_messaging` |
| Background Location | `geolocator` + background service |
| State Management | *(sesuaikan dengan pilihan tim — contoh: `riverpod` / `bloc`)* |
| Image Picker | `image_picker` |

---

## Struktur Folder

Rekomendasi struktur `lib/` agar rapi dan mudah navigasi:

```
frontend/
└── lib/
    ├── main.dart
    ├── config/
    │   └── app_config.dart        # base URL, WS config, dsb.
    ├── core/
    │   ├── api/
    │   │   ├── api_client.dart    # setup Dio/http + interceptor token
    │   │   └── endpoints.dart     # semua string endpoint
    │   ├── models/                # semua Dart model class (dari kontrak data)
    │   ├── services/
    │   │   ├── auth_service.dart
    │   │   ├── location_service.dart
    │   │   ├── websocket_service.dart
    │   │   └── notification_service.dart
    │   └── utils/
    │       └── secure_storage.dart
    ├── features/
    │   ├── auth/
    │   │   ├── screens/
    │   │   └── widgets/
    │   ├── radar/
    │   │   ├── screens/
    │   │   └── widgets/
    │   ├── merchant_profile/
    │   │   ├── screens/
    │   │   └── widgets/
    │   ├── selling/               # fitur pedagang (start/stop + GPS)
    │   │   ├── screens/
    │   │   └── widgets/
    │   ├── call/
    │   │   ├── screens/
    │   │   └── widgets/
    │   ├── review/
    │   │   ├── screens/
    │   │   └── widgets/
    │   └── admin/
    │       ├── screens/
    │       └── widgets/
    └── shared/
        ├── widgets/               # widget reusable (button, loader, dsb.)
        └── theme/
            └── app_theme.dart
```

---

## Branch & Workflow Git

### Branch yang kamu gunakan

```
mobile    ← branch kamu, jangan sentuh branch backend
```

### Aturan

- Semua pekerjaan frontend dilakukan dan di-push ke branch `mobile`.
- **Jangan pernah push ke branch `backend` atau `main`.**
- Semua fitur baru tetap di branch `mobile` — tidak perlu bikin branch per fitur.
- Kalau ada konflik atau butuh diskusi dengan BE, bicarakan dulu sebelum merge ke `main`.

### Alur kerja harian

```bash
# Sebelum mulai coding — pastikan branch dan kondisi repo terbaru
git checkout mobile
git pull origin mobile

# ... kerjakan fitur ...

# Staging file yang relevan saja (jangan git add . sembarangan)
git add lib/features/radar/screens/radar_screen.dart
git add lib/features/radar/widgets/merchant_marker.dart

# Commit dengan format konvensi
git commit -m "feat(radar): implement merchant markers on flutter_map"

# Push
git push origin mobile
```

---

## Konvensi Commit

Format: **`<type>(<scope>): <deskripsi singkat>`**

### Types

| Type | Kapan dipakai |
|---|---|
| `feat` | Menambah fitur atau screen baru |
| `fix` | Memperbaiki bug |
| `refactor` | Refactor kode tanpa mengubah tampilan/perilaku |
| `style` | Perubahan UI/styling tanpa logika |
| `chore` | Update pubspec, config, setup |
| `docs` | Update README atau komentar kode |

### Scopes untuk Frontend

`auth` · `radar` · `map` · `merchant-profile` · `selling` · `call` · `review` · `notification` · `admin` · `config` · `shared`

### Contoh commit message

```bash
feat(auth): add register screen with role selection
feat(auth): implement email verification screen and resend button
feat(radar): setup flutter_map with OpenStreetMap tile layer
feat(radar): add merchant markers with distance label
feat(radar): subscribe to reverb websocket channel on map open
fix(radar): fix markers not removed when merchant stops selling
feat(selling): implement start/stop selling toggle with GPS broadcast
feat(selling): add background location service for GPS update
feat(call): add location consent dialog before sending call request
feat(call): implement call button with 200m radius UI gate
fix(call): fix GPS accuracy check before call submission
feat(review): add rating input and review form screen
feat(merchant-profile): build merchant public profile screen
feat(merchant-profile): implement menu list with photo carousel
feat(merchant-profile): add edit profile and upload photo screen
feat(notification): integrate FCM for incoming call notification
chore: add flutter_map and geolocator to pubspec.yaml
chore(config): setup app_config.dart with base URL and WS config
style(radar): adjust marker icon color and size
```

> Satu commit = satu perubahan logis. Jangan gabungkan 3 fitur berbeda dalam 1 commit.

---

## Setup & Menjalankan Proyek

```bash
# 1. Masuk ke folder frontend
cd frontend

# 2. Install semua dependency
flutter pub get

# 3. Isi konfigurasi environment (lihat bagian Konfigurasi Environment)

# 4. Jalankan di emulator atau device
flutter run

# 5. Build APK (untuk testing/demo)
flutter build apk --release
```

**Pastikan Flutter SDK sudah terinstall dan emulator/device terhubung:**
```bash
flutter doctor
flutter devices
```

---

## Konfigurasi Environment

Buat file `lib/config/app_config.dart` dan isi dengan nilai dari tim backend:

```dart
class AppConfig {
  // Base URL REST API backend
  static const String baseUrl = 'https://YOUR_DOMAIN/api/v1';

  // WebSocket (Laravel Reverb) — minta ke tim backend
  static const String wsHost = 'YOUR_DOMAIN';
  static const int wsPort = 8080;              // default Reverb
  static const String reverbAppKey = 'YOUR_REVERB_APP_KEY'; // minta ke BE

  // Batas bisnis (jangan diubah tanpa diskusi)
  static const int radarRadiusMeters = 3000;   // 3 km
  static const int callRadiusMeters = 200;     // 200 m
  static const double callGpsAccuracyMax = 50.0; // maks 50 m
  static const int gpsUpdateIntervalSeconds = 10; // interval GPS merchant
}
```

> ⚠️ **Jangan commit nilai secret atau token ke repo.** Kalau perlu, tambahkan `app_config.dart` ke `.gitignore` dan buat `app_config.example.dart` sebagai template.

---

## Fitur & Screen Mapping

### Auth

| Screen | Fungsi | API yang dipanggil |
|---|---|---|
| Register | Form email, password, pilih role | `POST /auth/register` |
| Login | Form login | `POST /auth/login` |
| Verifikasi Email | Notifikasi cek email + tombol resend | `POST /auth/email/resend` |
| (deep link) | Handle link verifikasi dari email | `POST /auth/email/verify` |

### Radar (Buyer)

| Screen / Widget | Fungsi | API / WS |
|---|---|---|
| Radar Screen | Peta OpenStreetMap dengan marker pedagang aktif | `GET /radar/merchants` |
| Merchant Marker | Marker di peta, tap untuk lihat profil singkat | — |
| WS Listener | Subscribe ke channel geohash, update/hapus marker real-time | Reverb channel `private-radar.{geohash}` |
| Reconnect Handler | Saat WS putus & nyambung lagi, fetch ulang data radar | `GET /radar/merchants` |

### Profil Merchant (Buyer lihat)

| Screen | Fungsi | API |
|---|---|---|
| Merchant Profile Screen | Nama usaha, foto, deskripsi, rating agregat | `GET /merchants/{id}` |
| Menu List Screen | Daftar menu dengan harga dan foto | `GET /merchants/{id}/menus` |

### Profil & Menu (Merchant kelola sendiri)

| Screen | Fungsi | API |
|---|---|---|
| Edit Profil | Edit nama usaha, deskripsi | `GET /merchant/profile`, `PUT /merchant/profile` |
| Upload Foto Profil | Pilih dan upload foto profil usaha | `POST /merchant/profile/photo` |
| Tambah Menu | Form tambah menu baru | `POST /merchant/menus` |
| Edit Menu | Form edit menu | `PUT /merchant/menus/{id}` |
| Hapus Menu | Konfirmasi hapus menu | `DELETE /merchant/menus/{id}` |
| Upload Foto Menu | Pilih dan upload foto menu | `POST /merchant/menus/{id}/photos` |
| Hapus Foto Menu | Hapus foto menu | `DELETE /merchant/menu-photos/{id}` |

### Berjualan (Merchant)

| Screen / Service | Fungsi | API |
|---|---|---|
| Selling Toggle | Tombol "Mulai Berjualan" / "Berhenti Berjualan" | `POST /merchant/selling/start`, `POST /merchant/selling/stop` |
| Background GPS Service | Kirim update GPS setiap 10 detik saat aktif berjualan | `PUT /merchant/location` |

### Panggilan (Buyer)

| Screen / Widget | Fungsi | API |
|---|---|---|
| Call Button | Tombol panggil (aktif hanya jika ≤ 200m) | — |
| Location Consent Dialog | Dialog minta izin berbagi lokasi sebelum panggilan | — |
| POST Call | Kirim panggilan ke pedagang | `POST /calls` |
| Call History | Daftar riwayat panggilan | `GET /calls` |
| Call Detail | Detail satu panggilan | `GET /calls/{id}` |

### Ulasan (Buyer)

| Screen | Fungsi | API |
|---|---|---|
| Review Form | Rating bintang + teks opsional | `POST /calls/{id}/review` |
| Report Review | Form laporkan ulasan | `POST /reviews/{id}/reports` |

### Notifikasi

| Fungsi | Implementasi |
|---|---|
| Register FCM token ke backend saat login | `POST /auth/fcm-token` |
| Terima push notification panggilan masuk (merchant) | FCM + `firebase_messaging` |
| Hapus FCM token saat logout | `POST /auth/logout` (backend handle) |

### Admin

| Screen | Fungsi | API |
|---|---|---|
| Review Reports | Daftar laporan ulasan | `GET /admin/review-reports` |
| Hide Review | Tombol sembunyikan ulasan | `PATCH /admin/reviews/{id}/hide` |

---

## Kontrak API — Referensi untuk Flutter

> Gunakan field name ini **persis sama** saat parsing JSON response dari backend.

### Base URL & Header

```
Base URL : https://YOUR_DOMAIN/api/v1
Header   : Authorization: Bearer <token>
Format   : application/json
           multipart/form-data (khusus upload foto)
```

---

### Auth

#### `POST /auth/register`
```json
// Request
{ "email": "user@example.com", "password": "StrongPassword123!", "role": "buyer" }

// Response 201
{ "data": { "message": "Registrasi berhasil. Silakan verifikasi email Anda." } }
```

#### `POST /auth/login`
```json
// Request
{ "email": "user@example.com", "password": "StrongPassword123!" }

// Response 200
{
  "data": {
    "token": "<sanctum-bearer-token>",
    "token_type": "Bearer",
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "role": "buyer",
      "email_verified": true
    }
  }
}
```
> Simpan `token` di **`flutter_secure_storage`**, bukan SharedPreferences.

#### `POST /auth/logout` → `204` no body
#### `GET /auth/me` → sama dengan object `user` di login response
#### `POST /auth/email/verify` — `{ "token": "<dari-link-email>" }`
#### `POST /auth/email/resend` — no body, perlu token auth
#### `DELETE /account` → `204` no body

---

### Radar

#### `GET /radar/merchants?latitude=-7.47&longitude=112.43`
```json
// Response 200
{
  "data": [
    {
      "merchant_id": "uuid",
      "business_name": "Bakso Pak Budi",
      "latitude": -7.471,
      "longitude": 112.431,
      "distance_m": 145.7,
      "gps_accuracy_m": 12.0,
      "last_updated_at": "2026-10-09T10:00:00Z",
      "is_selling": true
    }
  ],
  "meta": {
    "radius_m": 3000,
    "websocket_channels": ["private-radar.9q5c", "private-radar.9q5f"]
  }
}
```
> Setelah dapat response ini, langsung subscribe ke semua channel di `websocket_channels`.

---

### Merchant Profile

#### `GET /merchant/profile` (merchant sendiri)
#### `PUT /merchant/profile` — `{ "business_name": "...", "description": "..." }`
#### `POST /merchant/profile/photo` — `multipart/form-data`, field: `photo`
```json
// Response 200
{
  "data": {
    "id": "uuid",
    "business_name": "Bakso Pak Budi",
    "description": "...",
    "profile_photo_url": "https://storage.supabase.co/...",
    "is_selling": false
  }
}
```

#### `GET /merchants/{id}` (buyer lihat profil publik)
```json
// Response 200
{
  "data": {
    "merchant_id": "uuid",
    "business_name": "Bakso Pak Budi",
    "description": "...",
    "profile_photo_url": "https://storage.supabase.co/...",
    "average_rating": 4.7,
    "total_reviews": 23,
    "is_selling": true
  }
}
```

#### `GET /merchants/{id}/menus`
```json
// Response 200
{
  "data": [
    {
      "id": "uuid",
      "name": "Bakso Biasa",
      "description": "Kuah bening.",
      "price": 15000.00,
      "is_available": true,
      "photos": [
        { "id": "uuid", "url": "https://storage.supabase.co/..." }
      ]
    }
  ]
}
```

---

### GPS & Selling

#### `POST /merchant/selling/start` → `{ "data": { "is_selling": true } }`
#### `POST /merchant/selling/stop` → `{ "data": { "is_selling": false } }`

#### `PUT /merchant/location`
```json
// Request
{
  "latitude": -7.471,
  "longitude": 112.431,
  "accuracy_m": 12.0,
  "recorded_at": "2026-10-09T10:00:00Z"
}
// Response 200
{ "data": { "message": "Lokasi berhasil diperbarui." } }
```

---

### Call

#### `POST /calls`
```json
// Request
{
  "merchant_id": "uuid",
  "share_location": true,
  "buyer_latitude": -7.471,
  "buyer_longitude": 112.431,
  "gps_accuracy_m": 15.0
}
// Response 201
{
  "data": {
    "call_id": "uuid",
    "status": "pending",
    "created_at": "2026-10-09T10:00:00Z"
  }
}
```

#### `GET /calls` — daftar riwayat
#### `GET /calls/{id}` — detail, ada field `has_review: bool`
#### `POST /calls/{id}/cancel` → `{ "data": { "id": "uuid", "status": "cancelled" } }`

---

### Review

#### `POST /calls/{id}/review`
```json
// Request
{ "rating": 5, "review_text": "Pelayanan ramah." }
// Response 201
{ "data": { "id": "uuid", "rating": 5, "created_at": "..." } }
```

#### `GET /merchants/{id}/rating` (publik, tidak perlu token)
```json
{ "data": { "merchant_id": "uuid", "average_rating": 4.7, "total_reviews": 23 } }
```

#### `POST /reviews/{id}/reports`
```json
// Request
{ "reason": "Ulasan mengandung kata-kata kasar." }
```

---

### Admin

#### `GET /admin/review-reports`
#### `PATCH /admin/reviews/{id}/hide` → `{ "data": { "id": "uuid", "moderation_status": "hidden" } }`

---

### Format Error Standar

Semua error dari backend menggunakan format ini — parse `error.code` untuk logika Flutter:

```json
{
  "error": {
    "code": "LOCATION_OUT_OF_RANGE",
    "message": "Pedagang berada di luar radius panggilan.",
    "details": {}
  }
}
```

| HTTP Code | Arti |
|---|---|
| `200` | Sukses |
| `201` | Resource dibuat |
| `204` | Sukses tanpa body |
| `400` | Request tidak valid |
| `401` | Token tidak valid / belum login |
| `403` | Tidak punya izin |
| `404` | Resource tidak ditemukan |
| `409` | Konflik / duplikasi |
| `422` | Validasi field gagal |
| `429` | Rate limit terlampaui |
| `500` | Error server |

| Error Code | Situasi |
|---|---|
| `EMAIL_NOT_VERIFIED` | Email belum diverifikasi saat login |
| `LOCATION_OUT_OF_RANGE` | Jarak > 200m saat panggilan |
| `GPS_ACCURACY_INSUFFICIENT` | Akurasi GPS > 50m |
| `CALL_RATE_LIMITED` | > 2 panggilan / 60 detik |
| `REVIEW_ALREADY_EXISTS` | Ulasan untuk call_id ini sudah ada |
| `MERCHANT_LOCATION_STALE` | Lokasi pedagang sudah > 30 detik |
| `MERCHANT_NOT_SELLING` | Pedagang tidak aktif berjualan |

---

## Kontrak WebSocket / Real-time

Koneksi ke **Laravel Reverb** menggunakan library yang kompatibel dengan Pusher protocol.

### Channel

| Channel | Format | Subscribe saat |
|---|---|---|
| Radar grid | `private-radar.{geohash}` | Setelah dapat response `GET /radar/merchants` |
| Merchant private | `private-merchant.{merchant_id}` | Setelah merchant login & aktif |

### Events yang didengarkan Flutter

#### `MerchantLocationUpdated` — update marker di peta
```json
{
  "merchant_id": "uuid",
  "business_name": "Bakso Pak Budi",
  "latitude": -7.471,
  "longitude": 112.431,
  "gps_accuracy_m": 12.0,
  "last_updated_at": "2026-10-09T10:00:00Z",
  "is_selling": true
}
```

#### `MerchantSellingStatusChanged` — tampilkan / hapus marker
```json
{
  "merchant_id": "uuid",
  "is_selling": false
}
```
> `is_selling: false` → hapus marker dari peta.

#### `IncomingCall` — notifikasi panggilan masuk ke merchant
```json
{
  "call_id": "uuid",
  "buyer_latitude": -7.471,
  "buyer_longitude": 112.431,
  "location_shared": true
}
```

#### `CallStatusUpdated` — update status panggilan
```json
{
  "call_id": "uuid",
  "status": "accept"
}
```

### Behavior saat reconnect

```
WS disconnect → reconnect
      ↓
Panggil GET /radar/merchants (REST API)
      ↓
Update semua marker dari response
      ↓
Subscribe ulang ke channel dari websocket_channels
```

---

## Kontrak Model Data (Dart Class Reference)

Gunakan field name berikut saat membuat model Dart (`fromJson`):

### `UserModel`
```dart
// JSON fields: id, email, role, email_verified
String id;
String email;
String role;         // "buyer" | "merchant" | "admin"
bool emailVerified;  // dari key "email_verified"
```

### `MerchantRadarItem`
```dart
// JSON fields: merchant_id, business_name, latitude, longitude,
//              distance_m, gps_accuracy_m, last_updated_at, is_selling
String merchantId;
String businessName;
double latitude;
double longitude;
double distanceM;
double gpsAccuracyM;
String lastUpdatedAt;  // ISO 8601
bool isSelling;
```

### `MerchantProfile`
```dart
// JSON fields: merchant_id / id, business_name, description,
//              profile_photo_url, average_rating, total_reviews, is_selling
String merchantId;
String businessName;
String? description;
String? profilePhotoUrl;
double averageRating;
int totalReviews;
bool isSelling;
```

### `MenuItem`
```dart
// JSON fields: id, merchant_id, name, description, price, is_available, photos
String id;
String merchantId;
String name;
String? description;
double price;
bool isAvailable;
List<MenuPhoto> photos;
```

### `MenuPhoto`
```dart
// JSON fields: id, url
String id;
String url;
```

### `CallModel`
```dart
// JSON fields: id, buyer_id, merchant_id, status,
//              location_consent, created_at, has_review
String id;
String buyerId;
String merchantId;
String status;        // "pending" | "accept" | "unanswered" | "cancelled" | "expired"
bool locationConsent;
String createdAt;     // ISO 8601
bool hasReview;
```

### `ReviewModel`
```dart
// JSON fields: id, rating, review_text, created_at
String id;
int rating;
String? reviewText;
String createdAt;
```

### `MerchantRating`
```dart
// JSON fields: merchant_id, average_rating, total_reviews
String merchantId;
double averageRating;
int totalReviews;
```

---

## Aturan Bisnis yang Harus Diterapkan di FE

Backend tetap validasi semua ini, tapi Flutter juga harus enforce di sisi UI agar UX-nya smooth:

| Aturan | Implementasi di Flutter |
|---|---|
| Radius radar **3 km** | Hanya tampilkan pedagang hasil `GET /radar/merchants` (sudah difilter BE) |
| Tombol panggil aktif hanya ≤ **200m** | Disable tombol jika `distance_m > 200` |
| Akurasi GPS panggilan ≤ **50m** | Cek akurasi GPS sebelum kirim `POST /calls`; jika > 50m, minta ulang lokasi dulu |
| GPS merchant setiap **10 detik** | Jalankan timer/background service saat `is_selling = true` |
| Stale location **> 30 detik** | Filter marker di peta: jangan tampilkan jika `last_updated_at` sudah > 30 detik |
| Consent lokasi wajib | **Wajib** tampilkan dialog izin sebelum set `share_location: true` |
| Format foto | Validasi ekstensi/MIME sebelum upload: hanya JPEG, PNG, WebP |
| Ukuran foto maks **2 MB** | Cek ukuran file sebelum upload; tampilkan error jika melebihi |
| Foto profil maks **1** | Tidak ada tombol tambah foto lagi jika sudah ada foto profil |
| Foto menu maks **5** | Disable tombol tambah foto jika sudah ada 5 foto |
| Rating **1–5** integer | Gunakan star rating widget, pastikan nilai 1–5 |
| Review text maks **500 karakter** | `maxLength: 500` di TextField |
| Ulasan tidak bisa diedit | Tidak ada tombol edit setelah review berhasil dikirim |
| Buyer tidak bisa lihat ulasan text merchant lain | Merchant hanya tampilkan `average_rating` dan `total_reviews` |
| Buyer hanya bisa buat ulasan jika `has_review: false` | Cek field `has_review` di detail panggilan sebelum tampilkan form review |

---

## State Management & Arsitektur

> Sesuaikan dengan pilihan tim. Ini rekomendasi jika belum ada keputusan:

- Gunakan **Riverpod** atau **BLoC** untuk state global (auth state, radar merchants, dsb.)
- Pisahkan **service layer** (API call) dari **UI layer** (screen/widget)
- Simpan `Bearer token` di `flutter_secure_storage`, load saat app start
- Gunakan interceptor (Dio) untuk otomatis attach header `Authorization` di setiap request

Contoh interceptor Dio:
```dart
dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) async {
    final token = await SecureStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  },
));
```

---

## Panduan Upload Foto

Upload foto menggunakan `multipart/form-data`. Field name yang dikirim ke backend:

| Endpoint | Field name |
|---|---|
| `POST /merchant/profile/photo` | `photo` |
| `POST /merchant/menus/{id}/photos` | `photo` |

Contoh dengan Dio:
```dart
Future<void> uploadProfilePhoto(File imageFile) async {
  final formData = FormData.fromMap({
    'photo': await MultipartFile.fromFile(
      imageFile.path,
      filename: 'profile.jpg',
      contentType: DioMediaType('image', 'jpeg'),
    ),
  });
  await dio.post('/merchant/profile/photo', data: formData);
}
```

Validasi sebelum upload:
- Format: JPEG, PNG, atau WebP saja
- Ukuran: maks 2 MB (`file.lengthSync() <= 2 * 1024 * 1024`)

---

## Catatan Penting

1. **Token disimpan di secure storage** — jangan pakai `SharedPreferences` untuk token autentikasi.
2. **Lokasi buyer tidak boleh dikirim** sebelum ada dialog consent eksplisit dari user.
3. **Setelah WebSocket reconnect**, selalu fetch ulang `GET /radar/merchants` sebelum subscribe channel lagi.
4. **Jangan hardcode nilai batas** (200m, 50m, 3km) di widget — taruh di `AppConfig`.
5. **Field `merchant_id` vs `id`** — perhatikan saat parsing response: endpoint radar pakai `merchant_id`, sedangkan profil merchant bisa pakai `id`. Konfirmasi ke BE jika ada inkonsistensi.
6. **Nilai `role` dan `status`** selalu lowercase: `"buyer"`, `"merchant"`, `"admin"`, `"pending"`, `"accept"`, dst.
7. **Semua ID adalah UUID string** — jangan diasumsikan integer.
8. **Waktu dalam ISO 8601** — gunakan `DateTime.parse()` untuk konversi.
9. **Merchant tidak bisa lihat radar pedagang lain** — jangan tampilkan halaman radar untuk user dengan role `merchant`.
10. **Admin endpoint** hanya aktif jika `user.role == "admin"`.

---

> **Koordinasi dengan tim backend:** minta nilai `REVERB_APP_KEY`, `REVERB_HOST`, dan `REVERB_PORT` setelah server live, lalu isi ke `AppConfig`.
