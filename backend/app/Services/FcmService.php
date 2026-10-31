<?php

namespace App\Services;

use App\Models\FcmToken;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FcmService
{
    /**
     * Kirim push notification ke seluruh perangkat milik user tertentu.
     *
     * @param  array<string, scalar>  $data
     */
    public function sendToUser(string $userId, string $title, string $body, array $data = []): int
    {
        if (! config('services.fcm.enabled', false)) {
            return 0;
        }

        $tokens = FcmToken::where('user_id', $userId)->pluck('token')->all();
        if (empty($tokens)) {
            return 0;
        }

        $stringData = [];
        foreach ($data as $k => $v) {
            $stringData[(string) $k] = (string) $v;
        }

        $sentCount = 0;
        $invalidTokens = [];

        foreach ($tokens as $token) {
            $status = $this->sendToToken($token, $title, $body, $stringData);
            if ($status === 'sent') {
                $sentCount++;
            } elseif ($status === 'unregistered') {
                $invalidTokens[] = $token;
            }
        }

        // Bersihkan token perangkat yang sudah tidak valid/uninstalled
        if (! empty($invalidTokens)) {
            FcmToken::whereIn('token', $invalidTokens)->delete();
        }

        return $sentCount;
    }

    /**
     * Kirim ke 1 device token via FCM HTTP v1 atau Legacy Server Key.
     *
     * @param  array<string, string>  $data
     * @return 'sent'|'unregistered'|'failed'|'skipped'
     */
    public function sendToToken(string $token, string $title, string $body, array $data = []): string
    {
        try {
            $projectId = config('services.fcm.project_id');
            $accessToken = $this->getHttpV1AccessToken();

            if ($projectId && $accessToken) {
                $response = Http::withToken($accessToken)
                    ->timeout(5)
                    ->post("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send", [
                        'message' => [
                            'token' => $token,
                            'notification' => [
                                'title' => $title,
                                'body' => $body,
                            ],
                            'data' => $data,
                            'android' => [
                                'priority' => 'HIGH',
                            ],
                        ],
                    ]);

                if ($response->successful()) {
                    return 'sent';
                }

                $errorCode = $response->json('error.details.0.errorCode') ?? $response->json('error.status');
                if ($response->status() === 404 || in_array($errorCode, ['UNREGISTERED', 'NOT_FOUND'], true)) {
                    return 'unregistered';
                }

                return 'failed';
            }

            $serverKey = config('services.fcm.server_key');
            if ($serverKey) {
                $response = Http::withHeaders([
                    'Authorization' => "key={$serverKey}",
                    'Content-Type' => 'application/json',
                ])
                    ->timeout(5)
                    ->post('https://fcm.googleapis.com/fcm/send', [
                        'to' => $token,
                        'priority' => 'high',
                        'notification' => [
                            'title' => $title,
                            'body' => $body,
                        ],
                        'data' => $data,
                    ]);

                if ($response->successful()) {
                    $error = $response->json('results.0.error');
                    if (in_array($error, ['NotRegistered', 'InvalidRegistration'], true)) {
                        return 'unregistered';
                    }

                    return $error ? 'failed' : 'sent';
                }

                return 'failed';
            }
        } catch (\Throwable $e) {
            Log::warning('FCM push failed: '.$e->getMessage());

            return 'failed';
        }

        return 'skipped';
    }

    /**
     * Ambil OAuth2 Access Token dari Service Account JSON (di-cache 55 menit).
     */
    protected function getHttpV1AccessToken(): ?string
    {
        $configuredAccessToken = config('services.fcm.access_token');
        if ($configuredAccessToken) {
            return (string) $configuredAccessToken;
        }

        $credentialsPath = config('services.fcm.credentials_path');
        if (! $credentialsPath) {
            return null;
        }

        $fullPath = file_exists($credentialsPath) ? $credentialsPath : base_path($credentialsPath);
        if (! is_file($fullPath)) {
            return null;
        }

        return Cache::remember('fcm_http_v1_oauth_token', 3300, function () use ($fullPath) {
            $json = json_decode((string) file_get_contents($fullPath), true);
            if (! is_array($json) || empty($json['client_email']) || empty($json['private_key'])) {
                return null;
            }

            $now = time();
            $header = $this->base64UrlEncode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
            $payload = $this->base64UrlEncode(json_encode([
                'iss' => $json['client_email'],
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => $json['token_uri'] ?? 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ]));

            $signature = '';
            if (! openssl_sign("{$header}.{$payload}", $signature, $json['private_key'], OPENSSL_ALGO_SHA256)) {
                return null;
            }

            $jwt = "{$header}.{$payload}.".$this->base64UrlEncode($signature);

            $response = Http::asForm()->timeout(5)->post($json['token_uri'] ?? 'https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ]);

            return $response->successful() ? $response->json('access_token') : null;
        });
    }

    private function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}

