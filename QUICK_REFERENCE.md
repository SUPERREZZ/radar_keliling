# 🎯 Quick Reference - Radar Keliling

**Untuk diskusi cepat dengan tim backend**

---

## 📌 Info Project

- **Repository**: https://github.com/SUPERREZZ/radar_keliling.git
- **Branch**: `frontend-dev` (37 commits)
- **Backend API**: http://backend.jh-beon.cloud/api/v1
- **Status**: Frontend 100%, Backend 90% (1 blocker)

---

## 🚨 Masalah

**Tidak bisa login** karena backend block user dengan `email_verified = false`

---

## ✅ Solusi (Copy-paste salah satu)

### **Opsi 1 - Database Seeder (RECOMMENDED):**
```bash
php artisan db:seed
```

### **Opsi 2 - Manual Update:**
```sql
UPDATE users SET email_verified = 1 WHERE email = 'test@example.com';
```

### **Opsi 3 - Kasih Token Manual:**
```sql
SELECT verification_token FROM users WHERE email = 'test@example.com';
```
Kasih tokennya ke kami untuk test fitur verifikasi.

### **Opsi 4 - Disable Sementara:**
Comment out di `LoginController.php`:
```php
// if (!$user->email_verified) {
//     throw new ApiException(...);
// }
```

---

## 📋 File Penting

| File | Gunakan Untuk |
|------|---------------|
| `CHAT_MESSAGE_BACKEND.txt` | Copy-paste ke chat/WA |
| `PESAN_UNTUK_BACKEND.md` | Penjelasan detail masalah |
| `UPDATE_UNTUK_BACKEND.md` | Setup email service lengkap |
| `EMAIL_VERIFICATION_FLOW.md` | Technical implementation |

---

## 🧪 Test Frontend Sekarang

```bash
cd c:\laragon\www\hacktest\radar_keliling\frontend\radar_keliling_app
flutter run -d chrome --web-port 3001
```

**Bisa test:** Splash, Login UI, Register, Email verification screen, Notifications

---

## 🎯 Timeline

**Butuh:** 1-2 hari untuk backend fix  
**Setelah fix:** Full testing semua fitur  
**Deadline:** Sebelum hackathon submission

---

## 📞 Next Action

1. **Kamu:** Share `CHAT_MESSAGE_BACKEND.txt` ke tim backend
2. **Backend:** Jalankan `php artisan db:seed`
3. **Test:** Login dengan `buyer@radar.test` / `password`
4. **Done:** Full testing! 🎉

---

**Questions?** Lihat dokumentasi lengkap di repository branch `frontend-dev`
