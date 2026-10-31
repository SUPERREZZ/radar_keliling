<?php

use App\Http\Controllers\Api\V1\AuthController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::get('/health', fn () => response()->json(['data' => ['status' => 'ok']]));

    Route::prefix('auth')->group(function () {
        Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:10,1');
        Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:10,1');

        // Email verification endpoints & aliases (rate-limited against brute-force, supports GET link click & POST)
        Route::match(['get', 'post'], '/email/verify', [AuthController::class, 'verifyEmail'])->middleware('throttle:10,1');
        Route::match(['get', 'post'], '/verify-email', [AuthController::class, 'verifyEmail'])->middleware('throttle:10,1');

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

    // Alias routes outside /auth prefix for /fcm/token, /account, and /broadcasting/auth
    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/broadcasting/auth', [\Illuminate\Broadcasting\BroadcastController::class, 'authenticate']);
        Route::delete('/account', [AuthController::class, 'deleteAccount']);
        Route::post('/fcm/token', [\App\Http\Controllers\Api\V1\FcmController::class, 'storeToken']);
        Route::delete('/fcm/token', [\App\Http\Controllers\Api\V1\FcmController::class, 'deleteToken']);

        // Merchant Profile, Menus, Location, & Calls Management
        Route::prefix('merchant')->middleware('merchant')->group(function () {
            Route::get('/dashboard', [\App\Http\Controllers\Api\V1\Merchant\MerchantProfileController::class, 'dashboard']);
            Route::get('/stats', [\App\Http\Controllers\Api\V1\Merchant\MerchantProfileController::class, 'dashboard']);
            Route::get('/profile', [\App\Http\Controllers\Api\V1\Merchant\MerchantProfileController::class, 'show']);
            Route::put('/profile', [\App\Http\Controllers\Api\V1\Merchant\MerchantProfileController::class, 'update']);
            Route::post('/profile/photo', [\App\Http\Controllers\Api\V1\Merchant\MerchantProfileController::class, 'uploadPhoto']);

            // Selling Status & Location
            Route::post('/selling/start', [\App\Http\Controllers\Api\V1\Merchant\MerchantLocationController::class, 'startSelling']);
            Route::post('/selling/stop', [\App\Http\Controllers\Api\V1\Merchant\MerchantLocationController::class, 'stopSelling']);
            Route::put('/location', [\App\Http\Controllers\Api\V1\Merchant\MerchantLocationController::class, 'updateLocation']);

            // Menu Management & Sorting
            Route::get('/menus', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'index']);
            Route::get('/menus/{id}', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'show']);
            Route::post('/menus', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'store']);
            Route::put('/menus/{id}', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'update']);
            Route::patch('/menus/{id}/availability', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'toggleAvailability']);
            Route::delete('/menus/{id}', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'destroy']);
            Route::post('/menus/{id}/photos', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'uploadPhoto']);
            Route::delete('/menu-photos/{id}', [\App\Http\Controllers\Api\V1\Merchant\MenuController::class, 'deletePhoto']);

            // Merchant Calls / Order Management & Sorting
            Route::get('/calls', [\App\Http\Controllers\Api\V1\CallController::class, 'index']);

            // Smart Buyer Hotspots (Heatmap for Merchant)
            Route::get('/radar/buyer-hotspots', [\App\Http\Controllers\Api\V1\HeatmapController::class, 'merchantHotspots']);
        });

        // Radar Endpoints (Buyer)
        Route::get('/radar/merchants', [\App\Http\Controllers\Api\V1\RadarController::class, 'merchants']);

        // Call Endpoints
        Route::post('/calls', [\App\Http\Controllers\Api\V1\CallController::class, 'store']);
        Route::get('/calls', [\App\Http\Controllers\Api\V1\CallController::class, 'index']);
        Route::get('/calls/{id}', [\App\Http\Controllers\Api\V1\CallController::class, 'show']);
        Route::post('/calls/{id}/answer', [\App\Http\Controllers\Api\V1\CallController::class, 'answer']);
        Route::post('/calls/{id}/accept', [\App\Http\Controllers\Api\V1\CallController::class, 'accept']);
        Route::post('/calls/{id}/unanswered', [\App\Http\Controllers\Api\V1\CallController::class, 'unanswered']);
        Route::post('/calls/{id}/cancel', [\App\Http\Controllers\Api\V1\CallController::class, 'cancel']);
        Route::post('/calls/{id}/complete', [\App\Http\Controllers\Api\V1\CallController::class, 'complete']);

        // Review & Moderation Endpoints
        Route::post('/calls/{id}/review', [\App\Http\Controllers\Api\V1\ReviewController::class, 'store']);
        Route::post('/reviews/{id}/reports', [\App\Http\Controllers\Api\V1\ReviewReportController::class, 'store']);

        // Admin Endpoints
        Route::prefix('admin')->middleware('admin')->group(function () {
            Route::get('/review-reports', [\App\Http\Controllers\Api\V1\ReviewReportController::class, 'adminIndex']);
            Route::get('/reviews', [\App\Http\Controllers\Api\V1\ReviewController::class, 'adminIndex']);
            Route::patch('/reviews/{id}/hide', [\App\Http\Controllers\Api\V1\ReviewController::class, 'hide']);
            Route::patch('/reviews/{id}/unhide', [\App\Http\Controllers\Api\V1\ReviewController::class, 'unhide']);
        });
    });

    // Public merchant endpoints (accessible without token)
    Route::get('/merchants/{id}', [\App\Http\Controllers\Api\V1\PublicMerchantController::class, 'show']);
    Route::get('/merchants/{id}/menus', [\App\Http\Controllers\Api\V1\PublicMerchantController::class, 'menus']);
    Route::get('/merchants/{id}/rating', [\App\Http\Controllers\Api\V1\PublicMerchantController::class, 'rating']);

    // Predictive Demand Heatmap (Spatial PostGIS AI)
    Route::get('/heatmap', [\App\Http\Controllers\Api\V1\HeatmapController::class, 'index']);
});