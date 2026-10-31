# 🎉 Update: Fitur Verifikasi Email Sudah Ditambahkan

## Status Update

Frontend sudah **upgrade** dengan fitur verifikasi email yang lengkap! Sekarang ada **3 cara** untuk user verify email mereka.

---

## ✅ Yang Sudah Dikerjakan (Frontend)

### **1. Deep Link Support** 🔗
User bisa klik link dari email dan langsung ter-verify otomatis.

**Example URL dari email:**
```
http://app.radarkeliling.com/verify?token=abc123xyz789
```

### **2. Manual Token Input** ⌨️
Jika email service belum jalan, user bisa:
1. Copy token dari database manual
2. Paste di aplikasi
3. Klik "Verifikasi"

**UI:** Toggle button + text field yang smooth.

### **3. Resend Email** 📤
User bisa request kirim ulang email jika:
- Email belum masuk
- Token sudah expired

**Rate Limiting:** Frontend siap terima error jika backend limit 3x per jam.

---

## 🚨 Yang Dibutuhkan dari Backend

### **SOLUSI 1: Quick Fix untuk Testing** ⭐ (Paling Mudah)

Untuk testing sekarang, backend bisa **disable email verification requirement sementara**:

```php
// File: app/Http/Controllers/Auth/LoginController.php

public function login(LoginRequest $request)
{
    $credentials = $request->validated();
    $user = User::where('email', $credentials['email'])->first();
    
    // COMMENT OUT baris ini untuk testing
    // if (!$user->email_verified) {
    //     throw new ApiException('Email belum diverifikasi.', 'EMAIL_NOT_VERIFIED', 403);
    // }
    
    // ... rest of login logic
}
```

**ATAU** jalankan database seeder:
```bash
php artisan db:seed
```

Ini akan create akun dengan `email_verified = 1`.

---

### **SOLUSI 2: Setup Email Service** (Untuk Production)

#### **Step 1: Pilih Email Service**

**Untuk Development (Recommended):**
```env
MAIL_MAILER=smtp
MAIL_HOST=sandbox.smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=your_mailtrap_username
MAIL_PASSWORD=your_mailtrap_password
MAIL_FROM_ADDRESS=noreply@radarkeliling.com
MAIL_FROM_NAME="Radar Keliling"
```

**Untuk Production:**
- **SendGrid** (Free tier: 100 email/day)
- **Mailgun** (Free tier: 5000 email/month)
- **Amazon SES** (Cheap dan reliable)

---

#### **Step 2: Create Email Template**

File: `resources/views/emails/verify-email.blade.php`

```blade
<!DOCTYPE html>
<html>
<head>
    <title>Verifikasi Email - Radar Keliling</title>
</head>
<body style="font-family: Arial, sans-serif; padding: 20px; background: #f6f8f7;">
    <div style="max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 12px;">
        <h1 style="color: #00875A; margin-bottom: 20px;">
            Verifikasi Email Radar Keliling
        </h1>
        
        <p style="color: #1A1A1A; font-size: 16px; line-height: 1.6;">
            Halo,<br>
            Terima kasih telah mendaftar di Radar Keliling.
        </p>
        
        <p style="color: #1A1A1A; font-size: 16px; line-height: 1.6;">
            Klik tombol di bawah untuk verifikasi email Anda:
        </p>
        
        <div style="text-align: center; margin: 30px 0;">
            <a href="{{ $verificationUrl }}" 
               style="display: inline-block; background: #00875A; color: white; 
                      padding: 14px 32px; text-decoration: none; border-radius: 8px; 
                      font-size: 16px; font-weight: 600;">
                Verifikasi Email
            </a>
        </div>
        
        <div style="background: #f6f8f7; padding: 16px; border-radius: 8px; margin: 20px 0;">
            <p style="color: #6B7280; font-size: 14px; margin: 0 0 8px 0;">
                Atau copy-paste token berikut di aplikasi:
            </p>
            <p style="font-family: monospace; font-size: 14px; color: #1A1A1A; 
                      margin: 0; word-break: break-all;">
                {{ $token }}
            </p>
        </div>
        
        <p style="color: #6B7280; font-size: 13px; line-height: 1.6;">
            Token berlaku selama 60 menit.
        </p>
        
        <hr style="margin: 30px 0; border: none; border-top: 1px solid #EEEEEE;">
        
        <p style="color: #6B7280; font-size: 12px; line-height: 1.6;">
            Jika Anda tidak mendaftar di Radar Keliling, abaikan email ini.
        </p>
    </div>
</body>
</html>
```

---

#### **Step 3: Update Register Controller**

```php
// File: app/Http/Controllers/Auth/RegisterController.php

use Illuminate\Support\Str;
use Illuminate\Support\Facades\Mail;
use App\Mail\VerifyEmailMail;

public function register(RegisterRequest $request)
{
    $validated = $request->validated();
    
    // Generate verification token
    $token = Str::random(64);
    
    $user = User::create([
        'email' => $validated['email'],
        'password' => Hash::make($validated['password']),
        'role' => $validated['role'],
        'email_verified' => false,
        'verification_token' => $token,
        'verification_token_expires_at' => now()->addHour(),
    ]);
    
    // Generate verification URL
    $verificationUrl = config('app.frontend_url') . '/verify?token=' . $token;
    
    // Send email
    try {
        Mail::to($user->email)->send(new VerifyEmailMail($user, $token, $verificationUrl));
    } catch (\Exception $e) {
        // Log error but don't fail registration
        \Log::error('Failed to send verification email: ' . $e->getMessage());
    }
    
    return response()->json([
        'data' => [
            'message' => 'Registrasi berhasil. Silakan verifikasi email Anda.'
        ]
    ], 201);
}
```

---

#### **Step 4: Create Mailable Class**

```bash
php artisan make:mail VerifyEmailMail
```

File: `app/Mail/VerifyEmailMail.php`

```php
<?php

namespace App\Mail;

use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

class VerifyEmailMail extends Mailable
{
    use Queueable, SerializesModels;

    public $user;
    public $token;
    public $verificationUrl;

    public function __construct(User $user, string $token, string $verificationUrl)
    {
        $this->user = $user;
        $this->token = $token;
        $this->verificationUrl = $verificationUrl;
    }

    public function build()
    {
        return $this->subject('Verifikasi Email - Radar Keliling')
                    ->view('emails.verify-email')
                    ->with([
                        'token' => $this->token,
                        'verificationUrl' => $this->verificationUrl,
                    ]);
    }
}
```

---

#### **Step 5: Implement Verification Endpoints**

```php
// File: app/Http/Controllers/Auth/VerificationController.php

public function verifyEmail(Request $request)
{
    $request->validate([
        'token' => 'required|string',
    ]);
    
    $user = User::where('verification_token', $request->token)
                ->where('verification_token_expires_at', '>', now())
                ->first();
    
    if (!$user) {
        return response()->json([
            'error' => [
                'code' => 'TOKEN_INVALID',
                'message' => 'Token tidak valid atau sudah kedaluwarsa.',
            ]
        ], 422);
    }
    
    $user->email_verified = true;
    $user->verification_token = null;
    $user->verification_token_expires_at = null;
    $user->save();
    
    return response()->json([
        'data' => [
            'message' => 'Email berhasil diverifikasi.'
        ]
    ]);
}

public function resendVerification(Request $request)
{
    $user = $request->user();
    
    if ($user->email_verified) {
        return response()->json([
            'error' => [
                'code' => 'ALREADY_VERIFIED',
                'message' => 'Email sudah diverifikasi.',
            ]
        ], 400);
    }
    
    // Rate limiting
    $cacheKey = "resend_count_{$user->id}";
    $recentSends = Cache::get($cacheKey, 0);
    
    if ($recentSends >= 3) {
        return response()->json([
            'error' => [
                'code' => 'RATE_LIMIT_EXCEEDED',
                'message' => 'Terlalu banyak permintaan. Coba lagi dalam 30 menit.',
            ]
        ], 429);
    }
    
    // Generate new token
    $token = Str::random(64);
    $user->verification_token = $token;
    $user->verification_token_expires_at = now()->addHour();
    $user->save();
    
    // Send email
    $verificationUrl = config('app.frontend_url') . '/verify?token=' . $token;
    Mail::to($user->email)->send(new VerifyEmailMail($user, $token, $verificationUrl));
    
    // Increment counter
    Cache::put($cacheKey, $recentSends + 1, now()->addHour());
    
    return response()->json([
        'data' => [
            'message' => 'Email verifikasi telah dikirim ulang.'
        ]
    ]);
}
```

---

#### **Step 6: Update .env**

```env
# Frontend URL (for email links)
FRONTEND_URL=http://app.radarkeliling.com

# Or for local testing:
FRONTEND_URL=http://localhost:3001
```

---

## 🧪 Testing Guide

### **Test Tanpa Email Service (Quick)**

Backend team bisa kasih token manual untuk testing:

```sql
-- 1. Register user baru via API atau manual INSERT
INSERT INTO users (id, email, password, role, email_verified, verification_token, verification_token_expires_at, created_at, updated_at)
VALUES (
    gen_random_uuid(),
    'test@example.com',
    '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- password: "password"
    'buyer',
    0,
    'abc123xyz789testtoken',
    NOW() + INTERVAL '1 hour',
    NOW(),
    NOW()
);

-- 2. Kasih token ke frontend team
-- Token: abc123xyz789testtoken

-- 3. Frontend test dengan URL:
-- http://localhost:3001/verify?token=abc123xyz789testtoken

-- 4. Atau frontend input manual di text field
```

---

### **Test Dengan Email Service**

```bash
# 1. Setup Mailtrap account (gratis)
# 2. Update .env dengan credentials Mailtrap
# 3. Test register via frontend
# 4. Check inbox di Mailtrap dashboard
# 5. Klik link di email
# 6. Should auto-verify dan redirect ke login
```

---

## 📊 Summary

| Fitur | Frontend | Backend |
|-------|----------|---------|
| Deep Link Verification | ✅ DONE | ⏳ Need email template |
| Manual Token Input | ✅ DONE | ✅ Endpoint ready (just need token generation) |
| Resend Email | ✅ DONE | ⏳ Need email service + rate limiting |
| Error Handling | ✅ DONE | ⏳ Need consistent error codes |
| Loading States | ✅ DONE | N/A |
| Auto-redirect | ✅ DONE | N/A |

---

## 🎯 Action Items

### **For Backend Team (Choose one):**

**Option A: Quick Testing (5 minutes)**
```bash
# Disable email verification temporarily
# OR
php artisan db:seed

# OR provide manual token:
SELECT verification_token FROM users WHERE email = 'test@example.com';
```

**Option B: Full Implementation (1-2 hours)**
1. Setup Mailtrap account
2. Create email template
3. Update RegisterController
4. Create VerifyEmailMail class
5. Implement verification endpoints
6. Test end-to-end

---

## 📞 Questions?

Jika ada yang tidak jelas atau butuh bantuan implementasi backend, silakan tanya!

**Frontend commits:** 36 total di branch `frontend-dev`
**Documentation:** `EMAIL_VERIFICATION_FLOW.md` (detail teknis lengkap)

---

**Next:** Setelah email verification fix, kita bisa full testing semua fitur! 🚀
