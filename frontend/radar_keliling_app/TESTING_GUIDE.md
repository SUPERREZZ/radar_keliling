# 🧪 Testing Guide - Radar Keliling

Panduan lengkap untuk testing manual aplikasi Radar Keliling dengan backend production.

## 📋 Prerequisites

- Flutter SDK installed
- Chrome/Edge browser (untuk web testing)
- Backend API: `http://backend.jh-beon.cloud/api/v1`
- API Docs: `http://backend.jh-beon.cloud/docs`

## 🚀 Quick Start

```bash
# Install dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome --web-port 8080

# Or run with hot reload
flutter run -d chrome --web-port 8080 --web-renderer html
```

## 📱 Test Scenarios

### 1️⃣ Testing sebagai BUYER (Pelanggan)

#### A. Registration & Verification
1. **Register akun buyer**
   - Buka aplikasi → Tap "Daftar"
   - Pilih role: "Pembeli"
   - Isi email & password (min 8 char)
   - Submit → Cek response "Silakan verifikasi email"

2. **Verify email**
   - Cek inbox email (atau gunakan token dari backend log)
   - Masukkan token verifikasi
   - Submit → Login otomatis

3. **Login**
   - Email & password yang sudah diverifikasi
   - Success → Navigate ke Radar screen

#### B. Radar - Cari Pedagang
1. **Izinkan GPS**
   - Browser akan minta permission lokasi → Allow
   - Map akan center ke lokasi Anda

2. **Lihat pedagang aktif**
   - Marker merah dengan pulse animation = pedagang yang sedang berjualan
   - Radius radar: 3km dari lokasi Anda
   - Real-time update setiap 10 detik

3. **Tap marker pedagang**
   - Bottom sheet muncul dengan info:
     - Nama bisnis
     - Deskripsi
     - Rating rata-rata
     - Jarak dari Anda
     - Menu items
   - Tombol "Panggil Pedagang"

#### C. Call Merchant - Panggil Pedagang
1. **Inisiasi panggilan**
   - Tap "Panggil Pedagang"
   - Dialog consent muncul: "Bagikan lokasi Anda?"
   - Pilih "Ya, Bagikan" atau "Tidak"

2. **Tracking status**
   - Status call: `pending` → `accepted` → `completed`
   - Jika share location: pedagang bisa lihat lokasi Anda (expired after 15 menit)
   - Real-time update via WebSocket

3. **Selesai transaksi**
   - Status berubah jadi `completed`
   - Navigate ke Review form

#### D. Review - Beri Ulasan
1. **Submit review**
   - Rating: 1-5 bintang
   - Text ulasan (optional)
   - Submit → Success message

2. **View reviews**
   - Lihat ulasan yang sudah dikirim di history

---

### 2️⃣ Testing sebagai MERCHANT (Pedagang)

#### A. Registration & Profile Setup
1. **Register akun merchant**
   - Daftar → Pilih role: "Pedagang"
   - Email & password
   - Verify email (sama seperti buyer)

2. **Setup profil merchant**
   - Setelah login pertama → Form profil muncul
   - Isi:
     - Nama bisnis (required, min 1 char)
     - Deskripsi bisnis
     - Upload foto profil (optional, max 2MB)
   - Submit → Navigate ke Selling Dashboard

3. **Tambah menu items**
   - Tab "Menu"
   - Tap "Tambah Menu"
   - Isi:
     - Nama item (required)
     - Deskripsi
     - Harga (format: Rp 15.000)
     - Toggle ketersediaan
     - Upload foto (max 5 foto per item)
   - Save

#### B. Selling - Berjualan
1. **Start selling**
   - Dashboard → Tap "Mulai Berjualan"
   - GPS akan aktif
   - Lokasi Anda dikirim ke server setiap 10 detik
   - Status: `is_selling = true`
   - Marker Anda muncul di radar buyer dalam radius 3km

2. **Monitor incoming calls**
   - Badge notifikasi muncul di tab "Panggilan"
   - Tap untuk lihat list panggilan pending
   - Real-time update via WebSocket

3. **Accept call**
   - Tap panggilan → Detail page
   - Tap "Terima Panggilan"
   - Status: `pending` → `accepted`
   - Jika buyer share location: lihat map dengan buyer location

4. **Complete transaction**
   - Setelah transaksi selesai
   - Tap "Selesaikan Panggilan"
   - Status: `accepted` → `completed`

5. **Stop selling**
   - Dashboard → Tap "Berhenti Berjualan"
   - GPS updates stop
   - Marker hilang dari radar buyer
   - Status: `is_selling = false`

#### C. Review Management
1. **View received reviews**
   - Tab "Profil" → Section "Ulasan"
   - Lihat semua rating & review dari buyer
   - Average rating ditampilkan

---

### 3️⃣ Testing sebagai ADMIN

#### A. Login admin
- Email: `admin@radarkeliling.com` (tanya ke backend team)
- Navigate ke Admin Reports screen

#### B. Review Moderation
1. **View flagged reviews**
   - List semua review dengan status `visible` / `hidden`

2. **Hide inappropriate review**
   - Tap review → "Sembunyikan Ulasan"
   - Status: `visible` → `hidden`
   - Review tidak tampil lagi di public

3. **Unhide review**
   - Filter: "Tersembunyi"
   - Tap review → "Tampilkan Kembali"
   - Status: `hidden` → `visible`

---

## 🔍 Testing Checklist

### Auth Flow
- [ ] Register buyer berhasil
- [ ] Register merchant berhasil
- [ ] Email verification berhasil
- [ ] Resend verification berhasil
- [ ] Login berhasil setelah verify
- [ ] Login gagal jika email belum verify
- [ ] Logout berhasil
- [ ] Token expired handling (401 → login screen)

### Buyer Flow
- [ ] GPS permission request
- [ ] Radar map loading
- [ ] Merchant markers tampil
- [ ] Pulse animation berjalan
- [ ] Bottom sheet merchant detail
- [ ] Menu items tampil
- [ ] Call merchant berhasil
- [ ] Call dengan location share
- [ ] Call tanpa location share
- [ ] Call status real-time update
- [ ] Submit review berhasil
- [ ] Review history tampil

### Merchant Flow
- [ ] Profile setup pertama kali
- [ ] Edit profile berhasil
- [ ] Add menu item berhasil
- [ ] Edit menu item berhasil
- [ ] Delete menu item berhasil
- [ ] Upload foto menu (max 5)
- [ ] Start selling berhasil
- [ ] GPS updates terkirim
- [ ] Incoming call notification
- [ ] Accept call berhasil
- [ ] View buyer location (jika di-share)
- [ ] Complete call berhasil
- [ ] Stop selling berhasil
- [ ] View received reviews

### Admin Flow
- [ ] Login sebagai admin
- [ ] View all reviews
- [ ] Hide review berhasil
- [ ] Unhide review berhasil
- [ ] Filter by status

### Real-time Features (WebSocket)
- [ ] Merchant location updates (setiap 10s saat selling)
- [ ] Buyer radar auto-refresh
- [ ] Call status notifications
- [ ] New call alerts untuk merchant

### Error Handling
- [ ] Network error → Snackbar muncul
- [ ] Validation error → Field error message
- [ ] 401 Unauthorized → Auto logout
- [ ] 404 Not Found → Error message
- [ ] GPS permission denied → Error dialog
- [ ] GPS accuracy too low → Warning message

---

## 🐛 Debugging Tips

### Check API calls
```dart
// lib/core/api/api_client.dart sudah include logging
// Lihat console untuk request/response details
```

### Check WebSocket connection
```dart
// lib/core/services/websocket_service.dart
// Console akan print connection status & events
```

### Test tanpa GPS
- Chrome DevTools → Sensors tab
- Override geolocation
- Custom lat/lng: Jakarta (-6.2088, 106.8456)

### Test dengan multiple accounts
1. Browser 1 (Normal): Login sebagai buyer
2. Browser 2 (Incognito): Login sebagai merchant
3. Test real-time interaction

### Backend API debugging
- Swagger UI: http://backend.jh-beon.cloud/docs
- Test endpoints langsung dari browser
- Check request/response format

---

## 📊 Expected API Responses

### Success Response
```json
{
  "data": {
    // ... resource data
  }
}
```

### Error Response
```json
{
  "message": "Error message",
  "errors": {
    "field": ["Validation error"]
  }
}
```

### 401 Unauthorized
```json
{
  "message": "Unauthenticated."
}
```

---

## 🚨 Known Issues / Limitations

1. **WebSocket Reverb Key**
   - `YOUR_REVERB_APP_KEY` masih placeholder
   - Minta key dari backend team untuk real-time features
   - Tanpa key: polling fallback (fetch setiap 10s)

2. **Email Verification**
   - Production: email real dikirim via SMTP
   - Development: cek backend log untuk token

3. **Photo Upload**
   - Max 2MB per file
   - Format: jpg, png, gif, webp
   - Backend resize & optimize otomatis

4. **GPS Accuracy**
   - Min accuracy: 50m untuk call
   - Browser GPS bisa kurang akurat di dalam ruangan
   - Mobile GPS lebih akurat

5. **WebSocket Reconnection**
   - Auto-reconnect jika connection lost
   - Max retry: 5x dengan exponential backoff

---

## 📞 Support

- Backend Issues: Contact backend team
- Frontend Issues: Check GitHub Issues
- API Docs: http://backend.jh-beon.cloud/docs

**Happy Testing! 🎉**
