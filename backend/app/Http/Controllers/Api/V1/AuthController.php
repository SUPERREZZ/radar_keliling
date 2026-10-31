<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\EmailVerificationToken;
use App\Models\User;
use App\Notifications\VerifyEmailNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = User::create([
            'email' => $request->email,
            'password' => $request->password,
            'role' => $request->role,
            'email_verified' => false,
        ]);

        $token = EmailVerificationToken::createForUser($user);
        $user->notify(new VerifyEmailNotification($token));

        return response()->json([
            'data' => ['message' => 'Registrasi berhasil. Silakan verifikasi email Anda.'],
        ], 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::where('email', $request->email)->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            throw new ApiException('INVALID_CREDENTIALS', 'Email atau password salah.', 401);
        }

        if (! $user->email_verified) {
            throw new ApiException('EMAIL_NOT_VERIFIED', 'Email belum diverifikasi.', 403);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'data' => [
                'token' => $token,
                'token_type' => 'Bearer',
                'user' => new UserResource($user),
            ],
        ]);
    }

    public function verifyEmail(Request $request): JsonResponse
    {
        $request->validate([
            'token' => ['required', 'string'],
        ]);

        $tokenHash = hash('sha256', trim((string) $request->token));

        $verification = EmailVerificationToken::where('token_hash', $tokenHash)
            ->whereNull('used_at')
            ->where('expires_at', '>', now())
            ->first();

        if (! $verification) {
            throw new ApiException('INVALID_VERIFICATION_TOKEN', 'Token verifikasi tidak valid atau telah kedaluwarsa.', 400);
        }

        $verification->update(['used_at' => now()]);

        $user = $verification->user;
        $user->update(['email_verified' => true]);

        return response()->json([
            'data' => [
                'message' => 'Email berhasil diverifikasi.',
            ],
        ]);
    }

    public function resendVerification(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user) {
            $request->validate([
                'email' => ['required', 'email'],
            ]);

            $user = User::where('email', strtolower(trim((string) $request->email)))->first();

            if (! $user) {
                throw new ApiException('USER_NOT_FOUND', 'Pengguna dengan email ini tidak ditemukan.', 404);
            }
        }

        if ($user->email_verified) {
            throw new ApiException('EMAIL_ALREADY_VERIFIED', 'Email sudah diverifikasi sebelumnya.', 400);
        }

        $token = EmailVerificationToken::createForUser($user);
        $user->notify(new VerifyEmailNotification($token));

        return response()->json([
            'data' => [
                'message' => 'Email verifikasi telah dikirim ulang.',
            ],
        ]);
    }

    public function logout(Request $request): Response
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();
    }

    public function me(Request $request): UserResource
    {
        return new UserResource($request->user());
    }
}
