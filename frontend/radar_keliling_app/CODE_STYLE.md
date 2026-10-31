# Code Style Guide — Radar Keliling Frontend

Panduan ini memastikan kode tetap clean, konsisten, dan mudah dibaca oleh tim backend.

---

## Naming Conventions

### File Names

```
snake_case.dart
```

Contoh:
- ✅ `merchant_profile_screen.dart`
- ❌ `MerchantProfileScreen.dart`
- ❌ `merchantProfileScreen.dart`

### Class Names

```dart
PascalCase
```

Contoh:
- ✅ `MerchantProfileScreen`
- ✅ `ApiClient`
- ✅ `RkButton`

### Variables, Functions, Parameters

```dart
camelCase
```

Contoh:
- ✅ `final merchantId = '...'`
- ✅ `void fetchRadar() { ... }`
- ❌ `final MerchantId = '...'`

### Private Members

Prefix dengan `_`:

```dart
class AuthNotifier {
  final AuthService _service;  // private
  
  void _init() { ... }         // private method
}
```

### Constants

```dart
static const camelCase
```

Contoh:
```dart
class AppConfig {
  static const String baseUrl = '...';
  static const int radarRadiusMeters = 3000;
}
```

---

## Folder & Import Structure

### Import Order

1. Dart SDK
2. Flutter
3. External packages
4. Internal (relative imports)

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user_model.dart';
import '../../../shared/widgets/rk_button.dart';
```

**Pisahkan setiap grup dengan 1 baris kosong.**

### Relative Imports

Gunakan relative path (`../`), **tidak** absolute (`package:radar_keliling/`).

✅ `import '../../../core/api/api_client.dart';`  
❌ `import 'package:radar_keliling/core/api/api_client.dart';`

---

## Formatting

### Line Length

Max **80 karakter** (Flutter standard). Gunakan auto-format:

```bash
flutter format lib/
```

### Trailing Commas

Selalu tambahkan trailing comma di argument terakhir:

```dart
RkButton(
  label: 'Submit',
  onPressed: _submit,
  isLoading: _loading,  // ← trailing comma
)
```

**Alasan:** Memudahkan git diff dan auto-format.

### Blank Lines

- 1 baris kosong antar method/function
- 2 baris kosong antar class (jika 1 file ada > 1 class)

---

## Widget Structure

### StatelessWidget

```dart
class MyWidget extends StatelessWidget {
  const MyWidget({super.key, required this.title});
  
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text(title),
    );
  }
}
```

### StatefulWidget

```dart
class MyWidget extends StatefulWidget {
  const MyWidget({super.key, required this.title});
  
  final String title;

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    // init code
  }

  @override
  void dispose() {
    // cleanup: controllers, listeners, timers
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text(widget.title),
    );
  }
}
```

### ConsumerWidget (Riverpod)

```dart
class MyWidget extends ConsumerWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(someProvider);
    return state.when(
      loading: () => CircularProgressIndicator(),
      error: (e, s) => Text('Error: $e'),
      data: (data) => Text(data),
    );
  }
}
```

---

## Riverpod Best Practices

### Provider Declaration

```dart
// ✅ Global provider di file service
final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.read(apiClientProvider)),
);

// ✅ StateNotifier di features/{fitur}/providers/
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(
  (ref) => AuthNotifier(ref.read(authServiceProvider)),
);

// ✅ FutureProvider dengan .family
final merchantProfileProvider = FutureProvider.family<MerchantProfile, String>(
  (ref, merchantId) => ref.read(merchantServiceProvider).getPublicProfile(merchantId),
);
```

### Accessing Providers

```dart
// ✅ Read in event handler
onPressed: () {
  ref.read(authProvider.notifier).logout();
}

// ✅ Watch for reactive rebuild
final user = ref.watch(authProvider).valueOrNull;

// ❌ Jangan watch di event handler
onPressed: () {
  ref.watch(authProvider.notifier).logout(); // SALAH
}
```

---

## Error Handling

### Try-Catch Pattern

```dart
Future<void> _submit() async {
  setState(() => _loading = true);
  try {
    await service.doSomething();
    if (!mounted) return;  // ← penting setelah async
    showRkSnackbar(context, 'Berhasil!');
  } on ApiException catch (e) {
    if (!mounted) return;
    showRkSnackbar(context, e.message, isError: true);
  } catch (_) {
    if (!mounted) return;
    showRkSnackbar(context, 'Terjadi kesalahan.', isError: true);
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

**Pattern wajib:**
1. Set loading state
2. Try-catch dengan `ApiException` lebih spesifik dulu
3. **Selalu cek `mounted` setelah `await`**
4. Finally untuk cleanup

---

## Async Best Practices

### Mounted Check

Setelah `await`, **selalu** cek `mounted` sebelum `setState` atau `Navigator`:

```dart
await someAsyncFunction();
if (!mounted) return;  // ← wajib
setState(() { ... });
```

### Future.wait untuk Paralel

```dart
// ✅ Paralel (lebih cepat)
final results = await Future.wait([
  fetchProfile(),
  fetchMenu(),
  fetchRating(),
]);

// ❌ Sequential (lambat)
final profile = await fetchProfile();
final menu = await fetchMenu();
final rating = await fetchRating();
```

---

## Animation Best Practices

### Controller Disposal

```dart
class _MyWidgetState extends State<MyWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();  // ← wajib
    super.dispose();
  }
}
```

### Animasi Sederhana

Gunakan `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSwitcher` jika cukup:

```dart
// ✅ Tidak perlu AnimationController
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  color: isActive ? Colors.blue : Colors.grey,
)
```

---

## Comments

### Kapan Harus Comment

✅ **Perlu:**
- Logika bisnis kompleks
- Workaround untuk bug library
- Magic number yang tidak jelas

❌ **Tidak perlu:**
- Kode yang self-explanatory
- Komentar yang redundan dengan nama function

```dart
// ✅ Good
// Backend butuh akurasi ≤ 50m untuk validasi panggilan
if (location.accuracyM > 50.0) { ... }

// ❌ Bad (redundant)
// Memanggil API login
await authService.login(email, password);
```

### Dokumentasi Function

Untuk public API / services:

```dart
/// Fetch pedagang aktif dalam radius 3km dari posisi buyer.
///
/// Mengembalikan [RadarResult] yang berisi list merchant dan
/// daftar WebSocket channel yang harus di-subscribe.
///
/// Throws [ApiException] jika request gagal.
Future<RadarResult> fetchRadar({
  required double latitude,
  required double longitude,
}) async { ... }
```

---

## Git Commit Style

Sudah dijelaskan di README, tapi ringkasnya:

```
<type>(<scope>): <deskripsi singkat>
```

**Types:** `feat`, `fix`, `refactor`, `style`, `chore`, `docs`, `test`

**Contoh:**
```
feat(radar): add real-time marker updates via WebSocket
fix(call): check mounted before setState after async call
refactor(auth): extract login logic to separate method
chore: update pubspec dependencies
```

---

## Things to Avoid

### ❌ Hardcoded Strings

```dart
// ❌
if (user.role == 'buyer') { ... }

// ✅
if (user.role == AppConstants.roleBuyer) { ... }
```

### ❌ Magic Numbers

```dart
// ❌
if (distance > 200) { ... }

// ✅
if (distance > AppConfig.callRadiusMeters) { ... }
```

### ❌ Deep Nesting

```dart
// ❌
if (a) {
  if (b) {
    if (c) {
      doSomething();
    }
  }
}

// ✅ Early return
if (!a) return;
if (!b) return;
if (!c) return;
doSomething();
```

### ❌ setState Setelah Async Tanpa Mounted Check

```dart
// ❌ DANGEROUS
await someFunction();
setState(() { _loading = false; });

// ✅
await someFunction();
if (mounted) setState(() { _loading = false; });
```

---

## Checklist Sebelum Commit

- [ ] `flutter analyze` — no warnings
- [ ] `flutter format lib/` — formatted
- [ ] Semua AnimationController di-dispose
- [ ] Mounted check setelah await
- [ ] Tidak ada hardcoded string/number
- [ ] Trailing commas di semua argument list
- [ ] Import sudah diurutkan (dart → flutter → package → internal)

---

Untuk pertanyaan style guide, tanya di grup tim atau refer ke [Effective Dart](https://dart.dev/guides/language/effective-dart).
