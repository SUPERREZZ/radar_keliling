<?php

use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

// Private channel untuk grid radar geohash (bisa di-subscribe oleh buyer maupun merchant yang telah login)
Broadcast::channel('radar.{geohash}', function (User $user) {
    return $user !== null;
});

// Private channel untuk notifikasi panggilan masuk & event personal merchant
Broadcast::channel('merchant.{merchantId}', function (User $user, string $merchantId) {
    return (string) $user->merchantProfile?->id === (string) $merchantId || (string) $user->id === (string) $merchantId;
});
