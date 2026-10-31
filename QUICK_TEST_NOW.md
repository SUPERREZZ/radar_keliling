# Quick Testing Guide - Tanpa Login

Meskipun ada blocker login, kamu tetap bisa test beberapa fitur frontend **sekarang juga**!

---

## 🚀 Cara Run Flutter App

```bash
cd c:\laragon\www\hacktest\radar_keliling\frontend\radar_keliling_app

# Clean build terlebih dahulu
flutter clean
flutter pub get

# Run di Chrome
flutter run -d chrome --web-port 3001
```

App akan buka di: `http://localhost:3001`

---

## ✅ Yang Bisa Ditest Sekarang (Tanpa Login)

### **1. Splash Screen Animation** 🎨
- Buka app, lihat splash screen dengan logo animated
- Logo muncul dengan bounce effect
- Text "Radar Keliling" fade in dari bawah
- Auto-navigate ke login page setelah 2 detik

**Expected**: Smooth animation, tidak ada lag

---

### **2. Login & Register UI/UX** 📱

#### Login Page:
- Lihat tampilan login form
- Coba isi email & password (tapi jangan submit dulu)
- Test TextField:
  - Focus effect (outline biru)
  - Password visibility toggle (icon mata)
  - Responsive keyboard
  
#### Register Page:
- Klik "Belum punya akun? Daftar"
- Lihat role selector dengan 2 card options:
  - **Pembeli** (buyer) - icon location
  - **Pedagang** (merchant) - icon store
- Test animasi hover/tap pada role card
- Coba isi form register (email, password, confirm password)

**Expected**: UI smooth, responsive, font Poppins terbaca jelas

---

### **3. Register Endpoint (Will Work!)** ✅

Kamu **BISA register** meskipun tidak bisa login:

1. Buka register page
2. Pilih role: **Pembeli** atau **Pedagang**
3. Isi form:
   - Email: `test123@example.com`
   - Password: `testing123`
   - Confirm Password: `testing123`
4. Klik "Daftar"

**Expected Response**: 
- Notifikasi animated **slide dari atas** dengan pesan:
  ```
  ✅ Registrasi berhasil! Silakan cek email Anda untuk verifikasi.
  ```
- UI smooth, tidak ada error
- Redirect ke login page

**Backend akan response sukses**, tapi untuk login butuh email verification.

---

### **4. Animated Notification System** 🎬

Setiap kali ada aksi (register, login attempt), perhatikan:

#### Success Notification (Hijau):
- Slide masuk dari **atas tengah**
- Smooth animation dengan curve `easeOutBack`
- Icon ✓ di sebelah kiri
- Shadow/elevation effect
- Auto-dismiss setelah 3 detik
- Bisa tap untuk dismiss manual

#### Error Notification (Merah):
- Same animation
- Icon ✗ di sebelah kiri
- Warna background red/pink

**Test**: Register beberapa kali dengan email berbeda, lihat notifikasi muncul.

---

### **5. Login Attempt (Will Fail, But Check UI)** ❌

Coba login dengan akun yang sudah kamu register:
- Email: `test123@example.com`
- Password: `testing123`

**Expected**: 
- Loading indicator muncul di button
- Setelah 1-2 detik, notifikasi merah slide dari atas:
  ```
  ❌ Email belum diverifikasi
  ```
- Tidak crash, tetap di login page
- Console log (F12) menampilkan detail error

**Ini normal! Backend memang block login tanpa email verified.**

---

## 🔍 Debug Console (F12)

Buka Chrome DevTools (tekan F12) untuk lihat debug logs:

### **Yang Harus Muncul:**

```
[Router] Redirecting from / to /splash (reason: initial)
[Router] Current route: /splash
[Router] User state: AsyncLoading
[Splash] Navigating to /login
[Router] Redirecting to /login
[AuthProvider] Initializing auth state
[AuthProvider] No stored token found
[AuthService] User logged out
```

### **Saat Register:**
```
[AuthService] Registering user: test123@example.com (role: buyer)
[ApiClient] POST http://backend.jh-beon.cloud/api/v1/auth/register
[ApiClient] Response 201: {data: {message: "Registrasi berhasil..."}}
[AuthService] Registration successful
```

### **Saat Login Attempt:**
```
[AuthService] Logging in: test123@example.com
[ApiClient] POST http://backend.jh-beon.cloud/api/v1/auth/login
[ApiClient] Error 403: {error: {code: "EMAIL_NOT_VERIFIED", message: "Email belum diverifikasi"}}
[AuthProvider] Login error: ApiException: Email belum diverifikasi
```

---

## 📸 Screenshot Checklist

Ambil screenshot untuk dokumentasi:
- [ ] Splash screen dengan logo animated
- [ ] Login page (clean UI)
- [ ] Register page (role selector)
- [ ] Success notification (hijau, slide dari atas)
- [ ] Error notification (merah)
- [ ] Console logs (F12) showing proper API calls

---

## ⚡ Troubleshooting

### **App tidak muncul / blank screen**
```bash
flutter clean
flutter pub get
flutter run -d chrome --web-port 3001
```

### **"flutter: command not found"**
Pastikan Flutter sudah terinstall:
```bash
flutter doctor
```

### **Error "XMLHttpRequest" atau CORS**
- Ini normal di web development
- Backend sudah setup CORS properly
- Kalau tetap error, coba restart app

### **Notification tidak muncul**
- Pastikan ada aksi (register/login attempt)
- Lihat console log untuk error details
- Notification auto-dismiss setelah 3 detik

---

## 📋 Next Steps After Backend Fix

Setelah tim backend jalankan database seeder atau fix email verification:

1. **Full Login Flow**
2. **Buyer Flow**:
   - Radar map dengan merchant markers
   - Tap marker → bottom sheet info
   - Call merchant button
   - Location consent dialog
   - Real-time call status

3. **Merchant Flow**:
   - Selling dashboard
   - Toggle "Mulai Berjualan" / "Berhenti Berjualan"
   - Accept/reject call dari buyer
   - View call history
   - See reviews

4. **Admin Flow**:
   - User reports
   - Merchant reports
   - Call reports

---

## 🎯 Summary

**Yang Bisa Test Sekarang:**
- ✅ Splash screen animation
- ✅ Login/Register UI
- ✅ Register endpoint (sukses, tapi tidak bisa login)
- ✅ Animated notifications
- ✅ Debug logging
- ✅ API integration (register works!)

**Yang Butuh Backend Fix:**
- ❌ Login (blocked by email verification)
- ❌ Authenticated endpoints
- ❌ Full user flow

---

Happy testing! 🚀 Kalau ada bug atau issue, langsung screenshot console logs (F12) dan UI nya.
