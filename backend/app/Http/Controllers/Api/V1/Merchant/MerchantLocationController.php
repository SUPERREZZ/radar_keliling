<?php

namespace App\Http\Controllers\Api\V1\Merchant;

use App\Events\MerchantLocationUpdated;
use App\Events\MerchantSellingStatusChanged;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\MerchantLocation;
use App\Models\MerchantProfile;
use App\Services\Geohash;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MerchantLocationController extends Controller
{
    private function getMerchantProfile(Request $request): MerchantProfile
    {
        $profile = $request->user()->merchantProfile;

        if (! $profile) {
            $profile = MerchantProfile::create([
                'user_id' => $request->user()->id,
                'business_name' => 'Pedagang Baru',
                'is_selling' => false,
            ]);
        }

        return $profile;
    }

    public function startSelling(Request $request): JsonResponse
    {
        $profile = $this->getMerchantProfile($request);
        $profile->update(['is_selling' => true]);

        // Cek geohash terakhir jika ada lokasi tersimpan untuk broadcast
        $geohash = null;
        $loc = DB::table('merchant_locations')
            ->selectRaw('ST_Y(current_location::geometry) as lat, ST_X(current_location::geometry) as lng')
            ->where('merchant_id', $profile->id)
            ->first();

        if ($loc) {
            $geohash = Geohash::encode((float) $loc->lat, (float) $loc->lng, 4);
            broadcast(new MerchantSellingStatusChanged($geohash, $profile->id, true));
        }

        return response()->json([
            'data' => [
                'is_selling' => true,
            ],
        ]);
    }

    public function stopSelling(Request $request): JsonResponse
    {
        $profile = $this->getMerchantProfile($request);
        $profile->update(['is_selling' => false]);

        $loc = DB::table('merchant_locations')
            ->selectRaw('ST_Y(current_location::geometry) as lat, ST_X(current_location::geometry) as lng')
            ->where('merchant_id', $profile->id)
            ->first();

        if ($loc) {
            $geohash = Geohash::encode((float) $loc->lat, (float) $loc->lng, 4);
            broadcast(new MerchantSellingStatusChanged($geohash, $profile->id, false));
        }

        return response()->json([
            'data' => [
                'is_selling' => false,
            ],
        ]);
    }

    public function updateLocation(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'accuracy_m' => ['required', 'numeric', 'min:0'],
            'recorded_at' => ['nullable', 'date'],
        ]);

        $profile = $this->getMerchantProfile($request);

        $lat = (float) $validated['latitude'];
        $lng = (float) $validated['longitude'];
        $accuracy = (float) $validated['accuracy_m'];
        $recordedAt = $validated['recorded_at'] ?? now()->toIso8601String();

        // Hitung jarak pergeseran dari titik GPS sebelumnya menggunakan PostGIS ST_Distance
        $previous = DB::selectOne('
            SELECT ROUND(ST_Distance(
                current_location,
                ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
            )::numeric, 2) as distance_moved_m
            FROM merchant_locations
            WHERE merchant_id = ?
        ', [$lng, $lat, $profile->id]);

        $distanceMovedM = $previous ? (float) $previous->distance_moved_m : null;

        MerchantLocation::updateCoordinates(
            $profile->id,
            $lat,
            $lng,
            $accuracy,
            $recordedAt
        );

        // Encode koordinat ke geohash grid (presisi 4)
        $geohash = Geohash::encode($lat, $lng, 4);

        // Broadcast event real-time ke WebSocket Reverb
        broadcast(new MerchantLocationUpdated(
            geohash: $geohash,
            merchantId: $profile->id,
            businessName: $profile->business_name,
            latitude: $lat,
            longitude: $lng,
            gpsAccuracyM: $accuracy,
            lastUpdatedAt: $recordedAt,
            isSelling: (bool) $profile->is_selling,
            distanceMovedM: $distanceMovedM
        ));

        return response()->json([
            'data' => [
                'message' => 'Lokasi berhasil diperbarui.',
                'distance_moved_m' => $distanceMovedM,
                'has_moved_5m' => $distanceMovedM === null || $distanceMovedM >= 5.0,
            ],
        ]);
    }
}