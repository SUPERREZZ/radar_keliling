<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\DB;

class CallResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $attributes = $this->resource->getAttributes();
        $hasPreloadedCoords = array_key_exists('buyer_latitude', $attributes)
            && array_key_exists('buyer_longitude', $attributes);

        $buyerLat = $attributes['buyer_latitude'] ?? null;
        $buyerLng = $attributes['buyer_longitude'] ?? null;
        $distanceM = $attributes['distance_m'] ?? null;

        $consentValid = (bool) $this->location_consent
            && ($this->location_expires_at === null || $this->location_expires_at->isFuture());

        if ($consentValid && ! $hasPreloadedCoords && ($buyerLat === null || $buyerLng === null)) {
            $coords = DB::selectOne('
                SELECT
                    ST_Y(c.buyer_location::geometry) AS lat,
                    ST_X(c.buyer_location::geometry) AS lng,
                    ROUND(ST_Distance(c.buyer_location, ml.current_location)::numeric, 1) AS distance_m
                FROM calls c
                LEFT JOIN merchant_locations ml ON ml.merchant_id = c.merchant_id
                WHERE c.id = ? AND c.buyer_location IS NOT NULL
            ', [$this->id]);

            if ($coords) {
                $buyerLat = $coords->lat !== null ? (float) $coords->lat : null;
                $buyerLng = $coords->lng !== null ? (float) $coords->lng : null;
                $distanceM = $coords->distance_m !== null ? (float) $coords->distance_m : null;
            }
        }

        return [
            'id' => $this->id,
            'call_id' => $this->id,
            'merchant_id' => $this->merchant_id,
            'buyer_id' => $this->buyer_id,
            'status' => $this->status,
            'location_consent' => (bool) $this->location_consent,
            'buyer_latitude' => $consentValid && $buyerLat !== null ? (float) $buyerLat : null,
            'buyer_longitude' => $consentValid && $buyerLng !== null ? (float) $buyerLng : null,
            'distance_m' => $consentValid && $distanceM !== null ? (float) $distanceM : null,
            'created_at' => $this->created_at?->toIso8601String(),
            'has_review' => (bool) $this->has_review,
        ];
    }
}
