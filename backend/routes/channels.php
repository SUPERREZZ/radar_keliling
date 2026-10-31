<?php

use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

// Private channel untuk grid radar geohash (bisa di-subscribe oleh buyer maupun merchant yang telah login)
Broadcast::channel('radar.{geohash}', function (User $user) {
    return $user !== null;
});

// Private channel untuk notifikasi panggilan masuk & event personal merchant
Broadcast::channel('merchant.{merchantId}', function (User $user, string $merchantId) {
    return (string) $user->merchantProfile?->id === (string) $merchantId
        || (string) $user->id === (string) $merchantId
        || $user->isAdmin();
});

// Private channel untuk status update panggilan (buyer dan merchant terkait)
Broadcast::channel('call.{callId}', function (User $user, string $callId) {
    $call = \App\Models\Call::select(['id', 'buyer_id', 'merchant_id'])->find($callId);
    if (! $call) {
        return false;
    }

    return (string) $user->id === (string) $call->buyer_id
        || (string) $user->merchantProfile?->id === (string) $call->merchant_id
        || $user->isAdmin();
});
