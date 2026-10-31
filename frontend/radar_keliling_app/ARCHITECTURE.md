# Radar Keliling — Frontend Architecture

## Struktur Folder

```
lib/
├── main.dart                      # Entry point aplikasi
├── config/
│   └── app_config.dart            # Konstanta konfigurasi (URL, WS, radius, dll)
├── core/
│   ├── api/
│   │   ├── api_client.dart        # DioClient + ApiException
│   │   └── endpoints.dart         # Semua string path endpoint
│   ├── constants.dart             # String constants (role, status, dll)
│   ├── models/                    # Data models (immutable, fromJson, copyWith)
│   ├── router.dart                # GoRouter + redirect logic
│   ├── services/                  # Business logic layer (API calls, GPS, WS)
│   └── utils/
│       └── secure_storage.dart    # Token storage (flutter_secure_storage)
├── features/
│   ├── auth/
│   │   ├── providers/             # Riverpod StateNotifiers
│   │   └── screens/               # Login, Register, VerifyEmail
│   ├── radar/
│   │   ├── providers/
│   │   ├── screens/               # RadarScreen (flutter_map)
│   │   └── widgets/               # MerchantMarker, MerchantBottomSheet
│   ├── merchant_profile/
│   │   ├── providers/
│   │   ├── screens/               # Profile view, Edit, Menu list
│   │   └── widgets/
│   ├── selling/
│   │   ├── providers/
│   │   ├── screens/               # SellingHomeScreen (toggle + GPS)
│   │   └── widgets/
│   ├── call/
│   │   ├── screens/               # History, Detail
│   │   └── widgets/               # CallButton
│   ├── review/
│   │   └── screens/               # ReviewFormScreen
│   └── admin/
│       ├── providers/
│       └── screens/               # AdminReportsScreen
└── shared/
    ├── theme/
    │   └── app_theme.dart         # AppColors + ThemeData
    └── widgets/                   # RkButton, RkTextField, RkSnackbar
```

---

## State Management

**Riverpod** — reactive state management dengan provider pattern.

### Provider Types

| Jenis | Kapan pakai |
|---|---|
| `Provider<T>` | Singleton / dependency injection (services, clients) |
| `StateNotifierProvider<N, T>` | State mutable yang reaktif (auth, radar, selling) |
| `FutureProvider<T>` | Data async dari API (profile, menu, calls) |

### Provider Locations

- **Global services:** `lib/core/services/` + provider di file yang sama
- **Feature state:** `lib/features/{fitur}/providers/`

---

## Alur Data

```
Screen → Provider → Service → API Client → Backend
  ↓                                            ↑
  StateNotifier updates state ←───────────────┘
  ↓
  UI rebuilds (Consumer / ref.watch)
```

### Contoh Auth Flow

```dart
LoginScreen
  → ref.read(authProvider.notifier).login(email, password)
  → AuthNotifier.login()
  → AuthService.login()
  → DioClient.post('/auth/login')
  → Backend response + token
  → SecureStorage.saveSession()
  → AuthNotifier updates state = AsyncValue.data(user)
  → GoRouter redirect → /radar (buyer) atau /selling (merchant)
```

---

## Error Handling

### API Errors

Backend mengirim format:
```json
{
  "error": {
    "code": "LOCATION_OUT_OF_RANGE",
    "message": "Pedagang berada di luar radius panggilan."
  }
}
```

`ApiException` di-throw dari `_AuthInterceptor.onError`, catch di UI:

```dart
try {
  await service.doSomething();
} on ApiException catch (e) {
  showRkSnackbar(context, e.message, isError: true);
}
```

### AsyncValue States

```dart
final state = ref.watch(someProvider);
state.when(
  loading: () => CircularProgressIndicator(),
  error: (e, s) => Text('Error: $e'),
  data: (data) => YourWidget(data),
);
```

---

## Animasi

**Prinsip:** Subtle, purposeful, tidak berlebihan.

### Animasi yang dipakai

| Komponen | Animasi | Tujuan |
|---|---|---|
| RkButton | Scale down 0.96 saat press | Tactile feedback |
| Merchant marker | Pulse ring 1.0 → 1.5 | Menarik perhatian merchant aktif |
| Selling toggle | Pulse 1.0 → 1.08 saat aktif | Indikasi live status |
| Star rating | Elastic scale | Playful interaction |
| Screen transition | Fade + slide up | Smooth entry |

### Animation Controllers

- **Dispose wajib:** Semua `AnimationController` harus di-dispose di `dispose()`
- **SingleTickerProviderStateMixin:** Untuk 1 animation controller
- **TickerProviderStateMixin:** Untuk > 1 animation controller

---

## Komunikasi Backend

### REST API

- Base URL: `AppConfig.baseUrl`
- Auth: `Authorization: Bearer <token>` (otomatis dari `_AuthInterceptor`)
- Semua endpoint di `Endpoints` class

### WebSocket (Laravel Reverb)

```dart
WebSocketService
  → connect (Pusher protocol)
  → subscribe ke channel dari BE: private-radar.{geohash}
  → listen event: MerchantLocationUpdated, MerchantSellingStatusChanged
  → update RadarNotifier state
  → UI rebuild otomatis (Consumer)
```

**Reconnect:** Setelah WS reconnect, `RadarNotifier.resync()` dipanggil otomatis untuk fetch ulang via REST.

---

## Keamanan

### Token Storage

- **flutter_secure_storage** — encrypted storage, bukan SharedPreferences
- Token disimpan di `SecureStorage.saveSession()`
- Token otomatis attached via `_AuthInterceptor`

### Location Consent

- Lokasi buyer **wajib** ada dialog consent sebelum dibagikan
- Dialog di `CallButton._showConsentDialog()`
- Jika user tap "Tidak", `share_location: false` dikirim ke backend

### Validasi Client-Side

- GPS accuracy ≤ 50m untuk panggilan
- Jarak ≤ 200m untuk panggilan (tombol disable)
- Foto maks 2 MB, format JPEG/PNG/WebP
- Teks ulasan maks 500 karakter

⚠️ **Semua validasi di-enforce ulang di backend** — client validation hanya untuk UX, bukan keamanan.

---

## Testing Strategy

### Unit Tests

```
test/
├── models/            # fromJson, copyWith
├── services/          # API calls (mock Dio)
└── providers/         # StateNotifier logic
```

### Widget Tests

```
test/
└── widgets/
    ├── rk_button_test.dart
    └── merchant_marker_test.dart
```

### Integration Tests

```
integration_test/
└── app_test.dart      # Full flow: login → radar → call
```

---

## Performance

### Optimizations

- `const` constructor untuk immutable widgets
- `flutter_map` hanya render marker di viewport
- `CachedNetworkImage` untuk foto (cache otomatis)
- WebSocket hanya subscribe channel yang relevan (geohash)
- Lazy load menu photos (carousel on demand)

### Bundle Size

- Tidak ada animasi Lottie/Rive (berat)
- Icon dari `Icons` built-in (tidak download font custom)
- Image format WebP untuk foto kecil

---

## Deployment Checklist

### Sebelum Build Production

- [ ] Ganti `AppConfig.baseUrl` ke production URL
- [ ] Ganti `AppConfig.wsHost` + `reverbAppKey` dari BE
- [ ] Tambahkan `google-services.json` (FCM)
- [ ] Set `AppConfig.wsTls = true`
- [ ] Build: `flutter build apk --release`
- [ ] Test di device fisik (bukan emulator)

---

## Kontak Backend

Jika ada:
- Field name tidak sesuai
- Status code atau error code baru
- Endpoint path berubah
- Event WebSocket baru

→ Update `Endpoints`, `AppConstants`, atau model yang relevan, lalu commit dengan prefix `fix(api):` atau `chore(api):`.
