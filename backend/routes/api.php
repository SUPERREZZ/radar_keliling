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

            // FCM device tokens
            Route::post('/fcm-token', [\App\Http\Controllers\Api\V1\FcmController::class, 'storeToken']);
            Route::delete('/fcm-token', [\App\Http\Controllers\Api\V1\FcmController::class, 'deleteToken']);
        });
    });

    // Alias routes outside /auth prefix for /fcm/token
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/fcm/token', [\App\Http\Controllers\Api\V1\FcmController::class, 'storeToken']);
        Route::delete('/fcm/token', [\App\Http\Controllers\Api\V1\FcmController::class, 'deleteToken']);

        // Merchant Profile & Menus
        Route::prefix('merchant')->middleware('merchant')->group(function () {
            Route::get('/profile', [\App\Http\Controllers\Api\V1\Merchant\MerchantProfileController::class, 'show']);
            Route::put('/profile', [\App\Http\Controllers\Api\V1\Merchant\MerchantProfileController::class, 'update']);
            Route::post('/profile/photo', [\App\Http\Controllers\Api\V1\Merchant\MerchantProfileController::class, 'uploadPhoto']);

            // Menu Management
            Route::get('/menus', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'index']);
            Route::get('/menus/{id}', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'show']);
            Route::post('/menus', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'store']);
            Route::put('/menus/{id}', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'update']);
            Route::delete('/menus/{id}', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'destroy']);
            Route::post('/menus/{id}/photos', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'uploadPhoto']);
            Route::delete('/menu-photos/{id}', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'deletePhoto']);
        });

        // Public merchant endpoints
        Route::get('/merchants/{id}', [\App\Http\Controllers\Api\V1\PublicMerchantController::class, 'show']);
        Route::get('/merchants/{id}/menus', [\App\Http\Controllers\Api\V1\PublicMerchantController::class, 'menus']);
        Route::get('/merchants/{id}/rating', [\App\Http\Controllers\Api\V1\PublicMerchantController::class, 'rating']);
    });
});