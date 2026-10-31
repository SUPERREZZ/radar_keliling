<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\DemandLog;
use App\Services\Geohash;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RadarController extends Controller
{
    /**
     * Cari pedagang terdekat berbasis kalkulasi spasial PostGIS.
     */
    public function merchants(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user && ! $user->isBuyer() && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya pembeli yang dapat menggunakan fitur radar.', 403);
        }

        $validated = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius' => ['nullable', 'integer', 'min:100', 'max:3000'],
        ]);

        $latitude = (float) $validated['latitude'];
        $longitude = (float) $validated['longitude'];
        $radius = min((int) ($validated['radius'] ?? config('radar.default_radius_m', 3000)), 3000);
        $staleSeconds = (int) config('radar.stale_seconds', 30);

        // Rekam riwayat pencarian pembeli untuk analitik spatial heatmap
        try {
            DemandLog::record($latitude, $longitude, $request->query('category'));
        } catch (\Throwable) {
            // Abaikan jika pencatatan analitik gagal agar request utama tidak terganggu
        }

        // Query geospasial PostGIS
        $results = DB::select("
            SELECT
                mp.id AS merchant_id,
                mp.business_name,
                ST_Y(ml.current_location::geometry) AS latitude,
                ST_X(ml.current_location::geometry) AS longitude,
                ROUND(ST_Distance(
                    ml.current_location,
                    ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
                )::numeric, 1) AS distance_m,
                ml.gps_accuracy_m,
                ml.last_updated_at,
                mp.is_selling
            FROM merchant_profiles mp
            INNER JOIN merchant_locations ml ON ml.merchant_id = mp.id
            WHERE mp.is_selling = TRUE
              AND ml.last_updated_at >= NOW() - (? || ' seconds')::interval
              AND ST_DWithin(
                    ml.current_location,
                    ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,
                    ?
              )
            ORDER BY distance_m ASC
        ", [
            $longitude,
            $latitude,
            $staleSeconds,
            $longitude,
            $latitude,
            $radius,
        ]);

        $merchants = array_map(function ($row) {
            return [
                'merchant_id' => $row->merchant_id,
                'business_name' => $row->business_name,
                'latitude' => (float) $row->latitude,
                'longitude' => (float) $row->longitude,
                'distance_m' => (float) $row->distance_m,
                'gps_accuracy_m' => (float) $row->gps_accuracy_m,
                'last_updated_at' => $row->last_updated_at,
                'is_selling' => (bool) $row->is_selling,
            ];
        }, $results);

        // Susun daftar channel WebSocket Reverb yang boleh di-subscribe buyer
        $buyerGeohash = Geohash::encode($latitude, $longitude, 4);
        $channels = ["private-radar.{$buyerGeohash}"];

        foreach ($merchants as $m) {
            $mGeohash = Geohash::encode($m['latitude'], $m['longitude'], 4);
            $channels[] = "private-radar.{$mGeohash}";
        }

        $channels = array_values(array_unique($channels));

        return response()->json([
            'data' => $merchants,
            'meta' => [
                'radius_m' => $radius,
                'websocket_channels' => $channels,
            ],
        ]);
    }
}