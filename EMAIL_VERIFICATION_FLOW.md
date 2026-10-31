# 📧 Email Verification Flow - Radar Keliling

## Overview

Fitur verifikasi email sudah **lengkap dan terintegrasi** dengan backend API production. Frontend mendukung **3 cara verifikasi**:

1. ✅ **Deep Link** (user klik link dari email)
2. ✅ **Manual Token Input** (user copy-paste token)
3. ✅ **Resend Email** (kirim ulang email verifikasi)

---

## 🎯 User Flow

### **Skenario 1: Deep Link (Recommended)**

```
1. User register → POST /v1/auth/register
2. Backend kirim email dengan link:
   http://app.radarkeliling.com/verify?token=abc123xyz789
3. User klik link dari email
4. App auto-detect token dari URL
5. App otomatis call POST /v1/auth/verify-email dengan token
6. Sukses → Redirect ke login page
7. User login dengan email yang sudah verified
```

**Expected Backend Email Content:**
```html
<h1>Verifikasi Email Radar Keliling</h1>
<p>Klik link berikut untuk verifikasi email Anda:</p>
<a href="http://app.radarkeliling.com/verify?token={{TOKEN}}">
  Verifikasi Email
</a>
<p>Token: {{TOKEN}}</p>
<p>Link berlaku selama 60 menit.</p>
```

---

### **Skenario 2: Manual Token Input**

```
1. User register → Redirect ke /verify?email=xxx
2. User buka email, COPY token (misal: abc123xyz789)
3. User klik "Punya token verifikasi? Masukkan manual"
4. User paste token di text field
5. User klik "Verifikasi"
6. App call POST /v1/auth/verify-email dengan token
7. Sukses → Redirect ke login page
```

**UI Features:**
- Toggle button untuk show/hide manual input
- TextField dengan hint "Paste token dari email"
- Validation: token tidak boleh kosong
- Loading state saat verifying
- Error handling dengan notifikasi jelas

---

### **Skenario 3: Resend Email**

```
1. User di halaman /verify
2. User belum terima email atau email kedaluwarsa
3. User klik "Kirim Ulang Email"
4. App call POST /v1/auth/resend-verification
5. Backend kirim email baru dengan token baru
6. Success indicator muncul
7. User lanjut dengan Skenario 1 atau 2
```

**Rate Limiting (Backend):**
- Maksimal 3x resend per 60 menit per akun
- Frontend menampilkan error jika rate limit exceeded

---

## 🔧 Technical Implementation

### **Frontend Components**

#### **1. Router Configuration** (`lib/core/router.dart`)
```dart
GoRoute(
  path: '/verify',
  builder: (_, state) {
    final email = state.uri.queryParameters['email'] ?? '';
    final token = state.uri.queryParameters['token']; // NEW!
    return VerifyEmailScreen(email: email, token: token);
  },
),
```

**Supported URLs:**
- `/verify?email=user@example.com` (after register)
- `/verify?token=abc123xyz789` (deep link from email)
- `/verify?email=user@example.com&token=abc123` (both)

---

#### **2. VerifyEmailScreen Features**

**Auto-Verify Logic:**
```dart
@override
void initState() {
  super.initState();
  // Auto-verify if token provided from deep link
  if (widget.token != null && widget.token!.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoVerify(widget.token!);
    });
  }
}

Future<void> _autoVerify(String token) async {
  setState(() => _verifying = true);
  try {
    await ref.read(authServiceProvider).verifyEmail(token);
    showRkSnackbar(context, '✅ Email berhasil diverifikasi!');
    await Future.delayed(const Duration(seconds: 2));
    context.go('/login');
  } catch (e) {
    // Auto-verify failed, show manual input
    setState(() => _showManualInput = true);
    showRkSnackbar(context, 'Verifikasi otomatis gagal...', isError: true);
  } finally {
    setState(() => _verifying = false);
  }
}
```

**Manual Input UI:**
```dart
if (_showManualInput) ...[
  Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      children: [
        Text('Masukkan Token Verifikasi'),
        TextField(
          controller: _tokenCtrl,
          decoration: InputDecoration(
            hintText: 'Paste token dari email',
          ),
        ),
        RkButton(
          label: 'Verifikasi',
          onPressed: _verifyManual,
          isLoading: _verifying,
        ),
      ],
    ),
  ),
],
```

**Resend Email:**
```dart
RkButton(
  label: 'Kirim Ulang Email',
  onPressed: _resend,
  isLoading: _resending,
  outlined: true,
  icon: Icons.refresh,
),
```

---

#### **3. AuthService Methods** (`lib/core/services/auth_service.dart`)

```dart
// Verify email with token
Future<void> verifyEmail(String token) async {
  await _api.post(Endpoints.emailVerify, data: {'token': token});
}

// Resend verification email
Future<void> resendVerification() async {
  await _api.post(Endpoints.emailResend);
}
```

**API Endpoints:**
- `POST /v1/auth/verify-email` → Body: `{"token": "abc123"}`
- `POST /v1/auth/resend-verification` → No body (uses auth token)

---

## 🔍 Testing Scenarios

### **Test 1: Deep Link Verification**

**Step 1 - Register:**
```bash
POST http://backend.jh-beon.cloud/api/v1/auth/register
Body: {"email": "test@example.com", "password": "testing123", "role": "buyer"}
Response: {"data": {"message": "Registrasi berhasil..."}}
```

**Step 2 - Get Token from Backend:**
```sql
-- Backend team jalankan query ini untuk ambil token
SELECT verification_token FROM users WHERE email = 'test@example.com';
-- Result: abc123xyz789
```

**Step 3 - Test Deep Link:**
```
Open app: http://localhost:3001/verify?token=abc123xyz789
```

**Expected:**
- Loading screen "Memverifikasi email..."
- Auto-call POST /v1/auth/verify-email
- Success notification
- Auto-redirect ke /login
- User bisa login

---

### **Test 2: Manual Token Input**

**Step 1 - Register & Go to Verify Screen:**
```
1. Register dengan email: manual@example.com
2. Auto-redirect ke /verify?email=manual@example.com
```

**Step 2 - Get Token:**
```sql
SELECT verification_token FROM users WHERE email = 'manual@example.com';
```

**Step 3 - Manual Input:**
```
1. Klik "Punya token verifikasi? Masukkan manual"
2. Paste token: abc123xyz789
3. Klik "Verifikasi"
```

**Expected:**
- Loading di button
- POST /v1/auth/verify-email
- Success notification
- Redirect ke login

---

### **Test 3: Resend Email**

**Step 1 - Go to Verify Screen:**
```
http://localhost:3001/verify?email=resend@example.com
```

**Step 2 - Click Resend:**
```
1. Klik "Kirim Ulang Email"
2. Wait for response
```

**Expected:**
- Loading di button
- POST /v1/auth/resend-verification
- Success indicator muncul
- Backend kirim email baru (check backend logs)

---

## ⚠️ Error Handling

### **Frontend Error Scenarios:**

| Error | Cause | Frontend Action |
|-------|-------|-----------------|
| Token kosong | User submit tanpa isi | Show notification "Token tidak boleh kosong" |
| Token invalid/expired | Backend return 422/400 | Show "Token salah atau kedaluwarsa" |
| Network error | No internet/timeout | Show "Gagal mengirim ulang. Coba lagi." |
| Rate limit exceeded | 3x resend dalam 1 jam | Show backend error message |

### **Backend Expected Errors:**

```json
// Token expired
{
  "error": {
    "code": "TOKEN_EXPIRED",
    "message": "Token verifikasi sudah kedaluwarsa."
  }
}

// Token invalid
{
  "error": {
    "code": "TOKEN_INVALID",
    "message": "Token verifikasi tidak valid."
  }
}

// Rate limit
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Terlalu banyak permintaan. Coba lagi dalam 30 menit."
  }
}
```

---

## 📋 Backend Requirements

### **1. Email Service Configuration**

Backend perlu setup email service (salah satu):

**Mailtrap (Development):**
```env
MAIL_MAILER=smtp
MAIL_HOST=sandbox.smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=your_username
MAIL_PASSWORD=your_password
MAIL_FROM_ADDRESS=noreply@radarkeliling.com
MAIL_FROM_NAME="Radar Keliling"
```

**Gmail (Quick Test):**
```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_app_password
MAIL_ENCRYPTION=tls
```

**SendGrid (Production):**
```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.sendgrid.net
MAIL_PORT=587
MAIL_USERNAME=apikey
MAIL_PASSWORD=your_sendgrid_api_key
```

---

### **2. Email Template**

File: `resources/views/emails/verify-email.blade.php`

```blade
<!DOCTYPE html>
<html>
<head>
    <title>Verifikasi Email - Radar Keliling</title>
</head>
<body style="font-family: Arial, sans-serif; padding: 20px;">
    <h1 style="color: #00875A;">Verifikasi Email Radar Keliling</h1>
    
    <p>Halo,</p>
    <p>Terima kasih telah mendaftar di Radar Keliling.</p>
    <p>Klik tombol di bawah untuk verifikasi email Anda:</p>
    
    <a href="{{ $verificationUrl }}" 
       style="display: inline-block; background: #00875A; color: white; 
              padding: 12px 24px; text-decoration: none; border-radius: 8px; 
              margin: 20px 0;">
        Verifikasi Email
    </a>
    
    <p>Atau copy-paste token berikut di aplikasi:</p>
    <p style="background: #f6f8f7; padding: 12px; border-radius: 8px; 
              font-family: monospace; font-size: 14px;">
        {{ $token }}
    </p>
    
    <p style="color: #6B7280; font-size: 13px;">
        Token berlaku selama 60 menit.
    </p>
    
    <hr style="margin: 30px 0; border: none; border-top: 1px solid #EEEEEE;">
    
    <p style="color: #6B7280; font-size: 12px;">
        Jika Anda tidak mendaftar di Radar Keliling, abaikan email ini.
    </p>
</body>
</html>
```

**Important Variables:**
- `$verificationUrl` → `http://app.radarkeliling.com/verify?token={{TOKEN}}`
- `$token` → Random string verification token

---

### **3. Backend Controller Implementation**

**Expected Behavior:**

```php
// POST /api/v1/auth/verify-email
public function verifyEmail(Request $request)
{
    $token = $request->input('token');
    
    $user = User::where('verification_token', $token)
                ->where('verification_token_expires_at', '>', now())
                ->first();
    
    if (!$user) {
        throw new ApiException(
            'Token tidak valid atau sudah kedaluwarsa.',
            'TOKEN_INVALID',
            422
        );
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
```

```php
// POST /api/v1/auth/resend-verification
public function resendVerification(Request $request)
{
    $user = $request->user();
    
    if ($user->email_verified) {
        throw new ApiException(
            'Email sudah diverifikasi.',
            'ALREADY_VERIFIED',
            400
        );
    }
    
    // Rate limiting check (3x per hour)
    $recentSends = Cache::get("resend_count_{$user->id}", 0);
    if ($recentSends >= 3) {
        throw new ApiException(
            'Terlalu banyak permintaan. Coba lagi dalam 30 menit.',
            'RATE_LIMIT_EXCEEDED',
            429
        );
    }
    
    // Generate new token
    $token = Str::random(64);
    $user->verification_token = $token;
    $user->verification_token_expires_at = now()->addHour();
    $user->save();
    
    // Send email
    Mail::to($user->email)->send(new VerifyEmailMail($user, $token));
    
    // Increment rate limit counter
    Cache::put("resend_count_{$user->id}", $recentSends + 1, now()->addHour());
    
    return response()->json([
        'data' => [
            'message' => 'Email verifikasi telah dikirim ulang.'
        ]
    ]);
}
```

---

## 🚀 Ready to Test

### **Frontend: READY ✅**
- Deep link handler
- Manual token input
- Resend email button
- Error handling
- Loading states
- Success notifications

### **Backend: NEED SETUP ⏳**
- [ ] Email service configuration (Mailtrap/SendGrid/Gmail)
- [ ] Email template creation
- [ ] Verification token generation in register
- [ ] verifyEmail() endpoint implementation
- [ ] resendVerification() endpoint implementation
- [ ] Rate limiting logic

---

## 📞 Questions for Backend Team

1. **Email Service:**
   - Sudah setup email service belum? (Mailtrap/SendGrid/Gmail)
   - Bisa test kirim email manual?

2. **Token Generation:**
   - Apakah `verification_token` sudah di-generate saat register?
   - Apakah `verification_token_expires_at` sudah diisi?

3. **Deep Link Domain:**
   - Domain apa yang dipakai untuk production?
   - `http://app.radarkeliling.com` atau yang lain?

4. **Testing:**
   - Bisa kasih 1 sample token untuk test?
   - Atau jalankan query: `SELECT verification_token FROM users WHERE email = 'test@example.com'`

---

## 🎯 Next Steps

### **For Backend Team:**
1. Setup email service (Mailtrap recommended untuk testing)
2. Implement email template
3. Test kirim email setelah register
4. Share 1 sample verification token untuk frontend testing

### **For Frontend:**
1. ✅ Deep link sudah ready
2. ✅ Manual input sudah ready
3. ✅ Resend button sudah ready
4. ⏳ Tunggu backend setup email service
5. 🧪 Test end-to-end setelah backend ready

---

**Last Updated**: 2026-10-31
**Status**: Frontend READY, Backend PENDING email service setup
