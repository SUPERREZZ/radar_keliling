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
            try {
                broadcast(new MerchantSellingStatusChanged($geohash, $profile->id, true));
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::warning('Reverb broadcast failed on startSelling: '.$e->getMessage());
            }
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
            try {
                broadcast(new MerchantSellingStatusChanged($geohash, $profile->id, false));
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::warning('Reverb broadcast failed on stopSelling: '.$e->getMessage());
            }
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
        $timestamp = date('Y-m-d H:i:sP', strtotime($recordedAt));

        // Kalkulasi jarak pergeseran & upsert lokasi dalam 1 atomic CTE query PostGIS
        $result = DB::selectOne('
            WITH prev AS (
                SELECT ROUND(ST_Distance(
                    current_location,
                    ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
                )::numeric, 2) AS distance_moved_m
                FROM merchant_locations
                WHERE merchant_id = ?
            ),
            upserted AS (
                INSERT INTO merchant_locations (merchant_id, current_location, gps_accuracy_m, last_updated_at)
                VALUES (?, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?, ?)
                ON CONFLICT (merchant_id) DO UPDATE SET
                    current_location = EXCLUDED.current_location,
                    gps_accuracy_m = EXCLUDED.gps_accuracy_m,
                    last_updated_at = EXCLUDED.last_updated_at
                RETURNING merchant_id
            )
            SELECT p.distance_moved_m
            FROM upserted u
            LEFT JOIN prev p ON TRUE
        ', [
            $lng,
            $lat,
            $profile->id,
            $profile->id,
            $lng,
            $lat,
            $accuracy,
            $timestamp,
        ]);

        $distanceMovedM = $result && $result->distance_moved_m !== null
            ? (float) $result->distance_moved_m
            : null;
        $hasMoved5m = $distanceMovedM === null || $distanceMovedM >= 5.0;

        // Broadcast event real-time ke WebSocket Reverb ketika lokasi awal atau bergeser >= 5 meter
        if ($hasMoved5m) {
            $geohash = Geohash::encode($lat, $lng, 4);

            try {
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
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::warning('Reverb broadcast failed on updateLocation: '.$e->getMessage());
            }
        }

        return response()->json([
            'data' => [
                'message' => 'Lokasi berhasil diperbarui.',
                'distance_moved_m' => $distanceMovedM,
                'has_moved_5m' => $hasMoved5m,
            ],
        ]);
    }
}