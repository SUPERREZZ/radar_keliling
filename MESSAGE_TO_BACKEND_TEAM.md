# Pesan untuk Tim Backend - Radar Keliling

## Status Integrasi Frontend ✅

Halo tim backend! Frontend sudah selesai dan terintegrasi 100% dengan production API kalian di `http://backend.jh-beon.cloud`. Semua endpoint sudah benar dengan prefix `/v1`.

**Commit terakhir**: 31 commits di branch `frontend-dev`
**API Docs yang digunakan**: http://backend.jh-beon.cloud/docs

---

## ⚠️ Blocker untuk Testing End-to-End

Saat ini frontend **tidak bisa login** karena requirement email verification. Kami perlu bantuan kalian untuk salah satu dari solusi berikut:

### **Solusi 1: Run Database Seeder (RECOMMENDED)** ⭐
Paling mudah dan cepat:
```bash
php artisan db:seed
```

Ini akan create akun testing:
- `buyer@radar.test` / `password`
- `merchant@radar.test` / `password`
- `admin@radar.test` / `password`

**Dengan email sudah terverifikasi.**

---

### **Solusi 2: Manual Update Database**
Jika seeder tidak bisa dijalankan, update manual:
```sql
-- Untuk akun yang sudah didaftarkan
UPDATE users SET email_verified = 1 WHERE email = 'test@example.com';

-- Atau buat akun baru langsung
INSERT INTO users (name, email, password, role, email_verified, created_at, updated_at)
VALUES (
  'Test Buyer',
  'buyer@test.com',
  '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- password: "password"
  'buyer',
  1,
  NOW(),
  NOW()
);
```

---

### **Solusi 3: Disable Email Verification (Temporary)**
Untuk testing saja, comment out di `LoginController.php`:
```php
public function login(LoginRequest $request)
{
    $credentials = $request->validated();
    
    // Comment out baris ini untuk testing
    // if (!$user->email_verified) {
    //     throw new ApiException('Email belum diverifikasi.', 'EMAIL_NOT_VERIFIED', 403);
    // }
    
    // ... rest of login logic
}
```

**⚠️ Ingat enable lagi sebelum production!**

---

## 🔍 Yang Sudah Kami Test

### ✅ **Working Endpoints**
```bash
# Health check
GET /api/v1/health
Response: {"data":{"status":"ok"}}

# Register
POST /api/v1/auth/register
Body: {"email":"test@example.com","password":"testing123","role":"buyer"}
Response: {"data":{"message":"Registrasi berhasil. Silakan verifikasi email Anda."}}
```

### ❌ **Blocked Endpoints**
```bash
# Login (blocked by email verification)
POST /api/v1/auth/login
Body: {"email":"test@example.com","password":"testing123"}
Response: {"error":{"code":"EMAIL_NOT_VERIFIED","message":"Email belum diverifikasi."}}

# Seeder accounts (tidak ada di database)
POST /api/v1/auth/login
Body: {"email":"buyer@radar.test","password":"password"}
Response: {"error":{"code":"INVALID_CREDENTIALS","message":"Email atau password salah."}}
```

---

## 📋 Info Tambahan yang Kami Butuhkan

### **1. Reverb WebSocket Key**
Untuk fitur real-time (call notifications), kami butuh:
```
REVERB_APP_KEY=your_actual_key_here
```
Dari file `.env` backend kalian.

### **2. Email Verification Flow**
Bagaimana cara user verify email di production?
- Apakah ada email service yang jalan?
- Apakah ada endpoint manual verify untuk testing?
- Format verification token seperti apa?

### **3. Database Migration Status**
Apakah semua migration sudah dijalankan? Terutama:
- `create_users_table`
- `create_merchants_table`
- `create_calls_table`
- `create_reviews_table`
- `create_call_reviews_table`

---

## 🧪 Cara Testing Setelah Fix

Setelah kalian jalankan salah satu solusi di atas:

1. **Kami akan test login:**
```bash
curl -X POST http://backend.jh-beon.cloud/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"buyer@radar.test","password":"password"}'
```

Expected: `{"data":{"token":"...", "user":{...}}}`

2. **Test authenticated endpoints:**
```bash
curl http://backend.jh-beon.cloud/api/v1/merchants \
  -H "Authorization: Bearer {token}"
```

3. **Test full flow di Flutter app:**
   - Login sebagai buyer
   - Lihat radar map dengan merchant markers
   - Call merchant
   - Login sebagai merchant
   - Toggle selling status
   - Accept call dari buyer

---

## 📞 Kontak

Jika ada pertanyaan atau butuh info lebih lanjut tentang frontend, silakan hubungi.

**Timeline yang kami harapkan**: 
- Solusi 1-3 dijalankan dalam **1-2 hari** agar bisa full testing sebelum deadline hackathon.

Terima kasih! 🙏
