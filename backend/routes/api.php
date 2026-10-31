<?php

use App\Http\Controllers\Api\V1\AuthController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::get('/health', fn () => response()->json(['data' => ['status' => 'ok']]));

    Route::prefix('auth')->group(function () {
        Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:10,1');
        Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:10,1');

        // Email verification endpoints & aliases
        Route::post('/email/verify', [AuthController::class, 'verifyEmail']);
        Route::post('/verify-email', [AuthController::class, 'verifyEmail']);

        Route::post('/email/resend', [AuthController::class, 'resendVerification'])->middleware('throttle:3,60');
        Route::post('/resend-verification', [AuthController::class, 'resendVerification'])->middleware('throttle:3,60');

        Route::middleware('auth:sanctum')->group(function () {
            Route::get('/me', [AuthController::class, 'me']);
            Route::post('/logout', [AuthController::class, 'logout']);
        });
    });
});
