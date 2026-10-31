<?php

use App\Models\Call;
use App\Models\EmailVerificationToken;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('radar:cleanup', function () {
    // 1. Hapus koordinat fisik buyer_location yang sudah melewati batas izin 15 menit (location_expires_at)
    $wipedLocations = DB::update('
        UPDATE calls
        SET buyer_location = NULL
        WHERE buyer_location IS NOT NULL
          AND location_expires_at IS NOT NULL
          AND location_expires_at <= ?
    ', [now()]);

    // 2. Ubah panggilan pending yang tidak direspons > 15 menit menjadi expired
    $expiredCalls = Call::where('status', Call::STATUS_PENDING)
        ->where('created_at', '<=', now()->subMinutes(15))
        ->update([
            'status' => Call::STATUS_EXPIRED,
            'buyer_location' => null,
        ]);

    // 3. Bersihkan token verifikasi email yang sudah kedaluwarsa
    $prunedTokens = EmailVerificationToken::where('expires_at', '<=', now())->delete();

    $this->info("Cleanup selesai: {$wipedLocations} lokasi pembeli dihapus, {$expiredCalls} panggilan expired, {$prunedTokens} token OTP dibersihkan.");
})->purpose('Bersihkan koordinat lokasi pembeli yang kedaluwarsa, auto-expire panggilan pending, dan hapus token OTP lama');

Schedule::command('radar:cleanup')->everyMinute()->withoutOverlapping();
