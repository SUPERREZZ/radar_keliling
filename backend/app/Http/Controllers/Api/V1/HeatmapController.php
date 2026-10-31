<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class HeatmapController extends Controller
{
    /**
     * Mengembalikan klaster hotspot permintaan pembeli menggunakan PostGIS ST_SnapToGrid + ST_Centroid.
     */
    public function index(Request $request): JsonResponse
    {
        $hour = $request->filled('hour') ? (int) $request->query('hour') : (int) now()->format('G');
        $hour = max(0, min(23, $hour));

        $category = $request->query('category');
        $gridSize = (float) ($request->query('grid_size') ?: 0.005);
        $gridSize = max(0.001, min(0.05, $gridSize));

        $query = "
            SELECT
                ROUND(ST_Y(ST_Centroid(ST_Collect(geom::geometry)))::numeric, 6) AS latitude,
                ROUND(ST_X(ST_Centroid(ST_Collect(geom::geometry)))::numeric, 6) AS longitude,
                ROUND((COUNT(id)::numeric / GREATEST(MAX(COUNT(id)) OVER(), 1)), 2) AS weight,
                COUNT(id) AS total_requests
            FROM demand_logs
            WHERE EXTRACT(HOUR FROM created_at) = ?
        ";

        $bindings = [$hour];

        if ($category !== null && $category !== '') {
            $query .= ' AND LOWER(kategori_pencarian) = LOWER(?) ';
            $bindings[] = $category;
        }

        $query .= '
            GROUP BY ST_SnapToGrid(geom::geometry, ?)
            HAVING COUNT(id) >= 1
            ORDER BY weight DESC, total_requests DESC
        ';
        $bindings[] = $gridSize;

        $results = DB::select($query, $bindings);

        $hotspots = array_map(function ($row) {
            return [
                'latitude' => (float) $row->latitude,
                'longitude' => (float) $row->longitude,
                'weight' => (float) $row->weight,
                'total_requests' => (int) $row->total_requests,
            ];
        }, $results);

        return response()->json([
            'data' => $hotspots,
            'meta' => [
                'hour' => $hour,
                'category' => $category,
                'grid_size' => $gridSize,
                'total_hotspots' => count($hotspots),
            ],
        ]);
    }

    /**
     * Endpoint rekomendasi hotspot cerdas untuk pedagang keliling.
     */
    public function merchantHotspots(Request $request): JsonResponse
    {
        $user = $request->user();
        $merchant = $user?->merchantProfile;

        // Ambil koordinat merchant jika tersedia
        $lat = $request->filled('latitude') ? (float) $request->query('latitude') : null;
        $lng = $request->filled('longitude') ? (float) $request->query('longitude') : null;

        if (($lat === null || $lng === null) && $merchant) {
            $loc = DB::table('merchant_locations')
                ->selectRaw('ST_Y(current_location::geometry) as lat, ST_X(current_location::geometry) as lng')
                ->where('merchant_id', $merchant->id)
                ->first();

            if ($loc) {
                $lat = (float) $loc->lat;
                $lng = (float) $loc->lng;
            }
        }

        $hour = $request->filled('hour') ? (int) $request->query('hour') : (int) now()->format('G');
        $hour = max(0, min(23, $hour));

        if ($lat !== null && $lng !== null) {
            $query = "
                SELECT
                    ROUND(ST_Y(ST_Centroid(ST_Collect(geom::geometry)))::numeric, 6) AS latitude,
                    ROUND(ST_X(ST_Centroid(ST_Collect(geom::geometry)))::numeric, 6) AS longitude,
                    ROUND((COUNT(id)::numeric / GREATEST(MAX(COUNT(id)) OVER(), 1)), 2) AS weight,
                    COUNT(id) AS total_requests,
                    ROUND(ST_Distance(
                        ST_Centroid(ST_Collect(geom::geometry))::geography,
                        ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
                    )::numeric, 1) AS distance_m
                FROM demand_logs
                WHERE EXTRACT(HOUR FROM created_at) = ?
                GROUP BY ST_SnapToGrid(geom::geometry, 0.005)
                HAVING COUNT(id) >= 1
                ORDER BY distance_m ASC, weight DESC
                LIMIT 10
            ";
            $results = DB::select($query, [$lng, $lat, $hour]);
        } else {
            $query = "
                SELECT
                    ROUND(ST_Y(ST_Centroid(ST_Collect(geom::geometry)))::numeric, 6) AS latitude,
                    ROUND(ST_X(ST_Centroid(ST_Collect(geom::geometry)))::numeric, 6) AS longitude,
                    ROUND((COUNT(id)::numeric / GREATEST(MAX(COUNT(id)) OVER(), 1)), 2) AS weight,
                    COUNT(id) AS total_requests,
                    NULL AS distance_m
                FROM demand_logs
                WHERE EXTRACT(HOUR FROM created_at) = ?
                GROUP BY ST_SnapToGrid(geom::geometry, 0.005)
                HAVING COUNT(id) >= 1
                ORDER BY weight DESC, total_requests DESC
                LIMIT 10
            ";
            $results = DB::select($query, [$hour]);
        }

        $hotspots = array_map(function ($row) {
            return [
                'latitude' => (float) $row->latitude,
                'longitude' => (float) $row->longitude,
                'weight' => (float) $row->weight,
                'total_requests' => (int) $row->total_requests,
                'distance_m' => $row->distance_m !== null ? (float) $row->distance_m : null,
                'recommendation' => sprintf(
                    'Hotspot dengan %d pencarian (bobot %.2f).%s',
                    $row->total_requests,
                    $row->weight,
                    $row->distance_m !== null ? sprintf(' Jarak dari Anda: ~%.0f meter.', $row->distance_m) : ''
                ),
            ];
        }, $results);

        return response()->json([
            'data' => $hotspots,
            'meta' => [
                'hour' => $hour,
                'total_recommendations' => count($hotspots),
            ],
        ]);
    }
}

