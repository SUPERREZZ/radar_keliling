# 🧪 Panduan Testing Manual Radar Keliling Frontend

## Status Saat Ini

Frontend **sudah lengkap dan siap** dari sisi code, tetapi **membutuhkan backend** untuk bisa jalan penuh. Saat ini app sudah berjalan di Chrome tapi stuck di login screen karena belum ada backend API.

---

## 🎯 Apa Yang Bisa Ditest Sekarang

### ✅ Yang Bisa Dilihat Langsung (Tanpa Backend):

1. **UI Components & Styling**
   - Semua tampilan sudah di-render dengan theme yang consistent
   - Button dengan animasi scale saat ditekan
   - Input fields dengan validation
   - Snackbar notifications
   - Loading states dengan CircularProgressIndicator

2. **Navigation Structure**
   - GoRouter setup sudah lengkap
   - Route protection berdasarkan auth state
   - Deep linking ready

3. **Layout & Responsiveness**
   - Semua screen sudah responsive
   - Scroll behavior smooth
   - Bottom sheets dan dialogs

---

## 📱 Cara Testing di Browser (Chrome)

### Yang Sudah Berhasil:
```bash
flutter run -d chrome
```

App sudah berjalan di **http://localhost:[port]** dan akan muncul **Login Screen**.

### Yang Bisa Kamu Lihat:

#### 1. **Login Screen** ✅
- Email & password input fields
- "Masuk" button dengan animation
- "Daftar akun baru" link
- Clean layout dengan logo/title

#### 2. **Register Screen** (navigasi dari login)
- Role selector (Pembeli/Pedagang) dengan radio buttons
- Email & password fields  
- Konfirmasi password
- "Daftar" button
- Sudah punya akun" link

#### 3. **Verify Email Screen** (setelah register)
- Email confirmation message
- Resend verification button
- Timer countdown (jika ada)

### Yang TIDAK Bisa Ditest (Perlu Backend):
- ❌ Actual login/register (submit form akan error karena API tidak ada)
- ❌ Navigate ke screens lain (butuh auth token)
- ❌ Load data merchants/menu
- ❌ GPS tracking
- ❌ WebSocket notifications

---

## 🔧 Cara Testing Lebih Lengkap (Setelah Backend Ready)

### Setup Yang Dibutuhkan:

1. **Update AppConfig**
   Edit `lib/config/app_config.dart`:
   ```dart
   static const bool isDemoMode = false; // Change to false
   static const String baseUrl = 'https://staging-api.url/api/v1';
   static const String reverbAppKey = 'actual-reverb-key';
   ```

2. **Run dengan Backend**
   ```bash
   flutter run -d chrome
   ```

3. **Test Flow Lengkap:**

   **A. Buyer Flow:**
   - Register as Pembeli
   - Verify email
   - Login
   - Open Radar → see nearby merchants
   - Tap merchant → see profile & menu
   - Call merchant → dialog consent location
   - Submit call → wait for merchant response
   - After transaction → write review with star rating

   **B. Merchant Flow:**
   - Register as Pedagang
   - Verify email
   - Login
   - Setup profile (business name, type, description)
   - Add menu items with photos & prices
   - Start Selling → GPS broadcast begins
   - Receive incoming calls from buyers
   - Accept/decline calls
   - Stop selling

   **C. Admin Flow:**
   - Login as admin
   - View reported reviews
   - Hide inappropriate reviews
   - View all merchants
   - Verify pending merchants

---

## 📸 Screenshots Tampilan (Yang Sudah Ada)

Saat ini kamu bisa screenshot:
1. ✅ Login Screen
2. ✅ Register Screen dengan Role Selector
3. ✅ Verify Email Screen

Yang belum bisa screenshot (butuh backend):
- ❌ Radar/Map dengan merchant markers
- ❌ Merchant profile & menu list
- ❌ Selling dashboard
- ❌ Call history & detail
- ❌ Review form
- ❌ Admin reports

---

## 🎬 Alternative Testing: Code Review

Karena belum bisa testing penuh tanpa backend, kamu bisa:

### 1. **Review Code Structure**
Cek folder structure di `lib/`:
```
lib/
├── main.dart
├── config/
│   ├── app_config.dart
│   └── app_theme.dart
├── core/
│   ├── models/          # ✅ 7 models lengkap
│   ├── services/        # ✅ 7 services lengkap
│   ├── api/             # ✅ DioClient + endpoints
│   ├── router.dart      # ✅ GoRouter setup
│   └── constants.dart   # ✅ String constants
├── features/
│   ├── auth/           # ✅ Login, Register, Verify
│   ├── radar/          # ✅ Map + markers + bottom sheet
│   ├── merchant_profile/  # ✅ Profile + menu
│   ├── selling/        # ✅ Dashboard + GPS broadcast
│   ├── call/           # ✅ History + detail + button
│   ├── review/         # ✅ Form dengan star rating
│   └── admin/          # ✅ Reports management
└── shared/
    ├── theme/          # ✅ Colors + typography
    └── widgets/        # ✅ RkButton, RkTextField, RkSnackbar
```

### 2. **Review Dokumentasi**
- `README.md` - API contract lengkap
- `ARCHITECTURE.md` - Penjelasan arsitektur
- `CODE_STYLE.md` - Coding standards
- `HANDOFF.md` - Integration guide

### 3. **Run Flutter Analyze**
```bash
cd frontend/radar_keliling_app
flutter analyze
```

Output: **Zero errors**, hanya info deprecation non-blocking ✅

---

## 🚀 Next Steps untuk Full Testing

### Option 1: Tunggu Backend Ready
1. Backend team deploy staging
2. Share credentials (base URL, Reverb key)
3. Update `AppConfig`
4. Full testing semua flow

### Option 2: Mock Backend (Advanced)
Buat mock API server dengan tools seperti:
- `json-server` untuk REST API
- `mockoon` untuk API mocking  
- Manual mock dengan interceptor di Dio

Tapi ini butuh effort tambahan dan tidak urgent untuk hackathon.

---

## 📝 Kesimpulan Testing Saat Ini

### ✅ Yang Sudah Bisa Diverifikasi:
- Code compile without errors
- Flutter analyze pass (zero errors)
- App berjalan di Chrome
- Login/Register screens tampil dengan baik
- UI components & theme sesuai design
- Navigation structure ready
- All 22 commits clean di GitHub

### ⏳ Yang Menunggu Backend:
- Actual authentication flow
- Data loading (merchants, menus, calls)
- GPS tracking & WebSocket
- Full user journey testing

### 🎖️ Status Overall:
**Frontend: READY FOR INTEGRATION** ✅

Code sudah clean, professional, dan siap untuk connect dengan backend segera setelah backend team deploy staging.

---

## 💡 Saran

Untuk **hackathon presentation**, kamu bisa:

1. **Demo UI/UX:**
   - Screenshot semua screens yang ada di code
   - Buat mockup flow dengan Figma/Canva
   - Explain architecture dari dokumentasi

2. **Code Walkthrough:**
   - Show folder structure yang rapi
   - Explain key features dari README
   - Highlight animations & UX details

3. **Integration Plan:**
   - Show HANDOFF.md untuk backend team
   - Explain API contract yang sudah disepakati
   - Demo `flutter analyze` output (zero errors)

**Good luck untuk hackathon-nya! 🚀**
