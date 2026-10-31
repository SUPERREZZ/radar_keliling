<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\FcmToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FcmController extends Controller
{
    public function storeToken(Request $request): JsonResponse
    {
        $token = $request->input('fcm_token') ?? $request->input('token');

        if (! $token || ! is_string($token)) {
            return response()->json([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Token FCM wajib diisi.',
                    'details' => ['fcm_token' => ['Field fcm_token atau token wajib disertakan.']],
                ],
            ], 422);
        }

        $deviceType = $request->input('device_type', 'android');

        // Reassign atau perbarui token perangkat ke user yang sedang login
        FcmToken::updateOrCreate(
            ['token' => trim($token)],
            [
                'user_id' => $request->user()->id,
                'device_type' => $deviceType,
                'last_seen_at' => now(),
            ]
        );

        return response()->json([
            'data' => [
                'message' => 'FCM token berhasil didaftarkan.',
            ],
        ]);
    }

    public function deleteToken(Request $request): JsonResponse
    {
        $token = $request->input('fcm_token') ?? $request->input('token');

        if ($token && is_string($token)) {
            $request->user()->fcmTokens()->where('token', trim($token))->delete();
        } else {
            // Jika token tidak disertakan, hapus semua token FCM milik akun ini
            $request->user()->fcmTokens()->delete();
        }

        return response()->json([
            'data' => [
                'message' => 'FCM token berhasil dihapus.',
            ],
        ]);
    }
}

