# Pesan untuk Tim Backend

## Status: Frontend Sudah Selesai ✅

Frontend sudah 100% siap dan terintegrasi dengan API production kalian di `http://backend.jh-beon.cloud/api/v1`

**Branch**: `frontend-dev` (33 commits)
**API Docs**: http://backend.jh-beon.cloud/docs

---

## 🚨 MASALAH: Tidak Bisa Login untuk Testing

### **Root Cause:**
Backend mengharuskan email terverifikasi (`email_verified = true`) sebelum login. 

Saat ini:
- ✅ Register berhasil
- ❌ Login ditolak dengan error: `"Email belum diverifikasi"`
- ❌ Akun seeder (`buyer@radar.test`, `merchant@radar.test`) tidak ada di database production

---

## 💡 SOLUSI (Pilih Salah Satu):

### **Opsi 1: Run Database Seeder** ⭐ (RECOMMENDED)
```bash
php artisan db:seed
```
Ini akan create akun testing dengan email sudah verified:
- `buyer@radar.test` / `password`
- `merchant@radar.test` / `password`
- `admin@radar.test` / `password`

### **Opsi 2: Manual Update Database**
```sql
UPDATE users SET email_verified = 1 WHERE email = 'test@example.com';
```
Ganti `test@example.com` dengan email yang sudah didaftarkan.

### **Opsi 3: Disable Email Verification Sementara**
Di `app/Http/Controllers/Auth/LoginController.php`, comment out validasi email:
```php
// if (!$user->email_verified) {
//     throw new ApiException('Email belum diverifikasi.', 'EMAIL_NOT_VERIFIED', 403);
// }
```
**⚠️ Ingat enable lagi sebelum production!**

---

## 📋 PERTANYAAN TAMBAHAN:

1. **Reverb WebSocket Key**
   Kami butuh `REVERB_APP_KEY` dari file `.env` backend untuk fitur real-time notifications.

2. **Email Service**
   Apakah email service sudah jalan di production? Kalau belum, bagaimana cara user verify email untuk testing?

3. **Migration Status**
   Apakah semua migration sudah dijalankan di production? (`php artisan migrate`)

---

## 🎯 YANG KAMI BUTUHKAN:

**Paling simple**: Jalankan `php artisan db:seed` di server production.

Setelah itu kami bisa:
- ✅ Login dengan akun seeder
- ✅ Test full flow buyer & merchant
- ✅ Test radar map dengan merchant markers
- ✅ Test call feature
- ✅ Test review system
- ✅ Finalize sebelum deadline hackathon

---

## ⏰ TIMELINE:

Kami harap solusi ini bisa dijalankan dalam **1-2 hari** agar bisa full testing sebelum deadline.

Terima kasih! 🙏
