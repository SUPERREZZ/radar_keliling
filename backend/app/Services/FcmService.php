<?php

namespace App\Services;

use App\Models\FcmToken;
use App\Models\User;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FcmService
{
    protected ?string $serviceAccountPath = null;
    protected ?array $serviceAccount = null;

    public function __construct()
    {
        $possiblePaths = [
            config('services.firebase.credentials') ?? env('FIREBASE_CREDENTIALS'),
            config('services.fcm.credentials_path'),
            storage_path('app/private/firebase/service-account.json'),
            storage_path('app/firebase/service-account.json'),
            base_path('firebase-service-account.json'),
        ];

        foreach ($possiblePaths as $path) {
            if ($path && file_exists($path)) {
                $this->serviceAccountPath = $path;
                $decoded = json_decode(file_get_contents($path), true);
                if (is_array($decoded) && isset($decoded['private_key'], $decoded['client_email'], $decoded['project_id'])) {
                    $this->serviceAccount = $decoded;
                    break;
                }
            }
        }
    }

    /**
     * Kirim notifikasi push ke semua perangkat milik user berdasarkan ID atau instance User.
     */
    public function sendToUser(
        string|User $userId,
        string $title,
        string $body,
        array $data = []
    ): int {
        $user = $userId instanceof User ? $userId : User::find($userId);

        if (! $user) {
            Log::info("[FCM] User tidak ditemukan untuk pengiriman notifikasi.");
            return 0;
        }

        $tokens = $user->fcmTokens()->pluck('token')->filter()->all();
        if (empty($tokens)) {
            Log::info("[FCM] User {$user->id} tidak memiliki token FCM perangkat yang terdaftar.");
            return 0;
        }

        $sentCount = 0;
        foreach ($tokens as $token) {
            if ($this->sendToToken($token, $title, $body, $data)) {
                $sentCount++;
            }
        }

        return $sentCount;
    }

    /**
     * Kirim notifikasi push ke satu token perangkat tertentu via Google Firebase Cloud Messaging v1 API.
     */
    public function sendToToken(
        string $token,
        string $title,
        string $body,
        array $data = []
    ): bool {
        $projectId = $this->getProjectId();
        $accessToken = $this->getAccessToken();

        if (! $projectId || ! $accessToken) {
            Log::warning('[FCM] Project ID atau Access Token FCM tidak tersedia. Pengiriman dilewati.');
            return false;
        }

        $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";

        // Konversi seluruh nilai payload data menjadi string (syarat ketat FCM v1 API)
        $stringData = [];
        foreach ($data as $key => $value) {
            $stringData[(string) $key] = is_null($value) ? '' : (string) $value;
        }

        $payload = [
            'message' => [
                'token' => $token,
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                ],
                'data' => $stringData,
                'android' => [
                    'priority' => 'HIGH',
                    'notification' => [
                        'channel_id' => 'radar_keliling_calls',
                        'sound' => 'default',
                        'default_vibrate_timings' => true,
                        'default_light_settings' => true,
                    ],
                ],
            ],
        ];

        try {
            $response = Http::withToken($accessToken)
                ->timeout(10)
                ->post($url, $payload);

            if ($response->successful()) {
                Log::info('[FCM] Push notifikasi berhasil dikirim (token prefix: ' . substr($token, 0, 12) . '...).');
                return true;
            }

            Log::error('[FCM] Error respons dari FCM (' . $response->status() . '): ' . $response->body());

            // Bersihkan token yang sudah expired / unregistered dari database
            if ($response->status() === 404 || str_contains($response->body(), 'UNREGISTERED')) {
                FcmToken::where('token', $token)->delete();
                Log::info('[FCM] Menghapus token tidak valid / unregistered dari database.');
            }

            return false;
        } catch (\Throwable $e) {
            Log::error('[FCM] Exception saat mengirim push notifikasi: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Ambil Project ID dari konfigurasi atau service account.
     */
    protected function getProjectId(): ?string
    {
        return config('services.fcm.project_id')
            ?? ($this->serviceAccount['project_id'] ?? null)
            ?? env('FIREBASE_PROJECT_ID', 'radarkeliling-3d57f');
    }

    /**
     * Ambil atau cache Google OAuth2 Access Token selama 50 menit.
     */
    protected function getAccessToken(): ?string
    {
        $configuredAccessToken = config('services.fcm.access_token');
        if ($configuredAccessToken) {
            return (string) $configuredAccessToken;
        }

        if (! $this->serviceAccount) {
            return null;
        }

        return Cache::remember('fcm_google_access_token', now()->addMinutes(50), function () {
            $jwt = $this->createSignedJwt();
            if (! $jwt) {
                return null;
            }

            $response = Http::asForm()->timeout(10)->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ]);

            if ($response->successful()) {
                return $response->json('access_token');
            }

            Log::error('[FCM] Gagal pertukaran token OAuth2: ' . $response->body());
            return null;
        });
    }

    /**
     * Buat Signed JWT (RFC 7523) untuk otentikasi Google Service Account.
     */
    protected function createSignedJwt(): ?string
    {
        if (! $this->serviceAccount) {
            return null;
        }

        $header = ['alg' => 'RS256', 'typ' => 'JWT'];
        $now = time();
        $claims = [
            'iss' => $this->serviceAccount['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3600,
        ];

        $base64UrlHeader = $this->base64UrlEncode(json_encode($header));
        $base64UrlClaims = $this->base64UrlEncode(json_encode($claims));

        $dataToSign = "{$base64UrlHeader}.{$base64UrlClaims}";
        $signature = '';

        $privateKey = openssl_pkey_get_private($this->serviceAccount['private_key']);
        if (! $privateKey) {
            Log::error('[FCM] Private key tidak valid di service-account.json');
            return null;
        }

        $signed = openssl_sign($dataToSign, $signature, $privateKey, OPENSSL_ALGO_SHA256);
        if (! $signed) {
            Log::error('[FCM] openssl_sign gagal untuk JWT');
            return null;
        }

        $base64UrlSignature = $this->base64UrlEncode($signature);

        return "{$dataToSign}.{$base64UrlSignature}";
    }

    protected function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}
