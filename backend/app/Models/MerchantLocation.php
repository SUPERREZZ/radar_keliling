<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\DB;

class MerchantLocation extends Model
{
    use HasFactory;

    protected $primaryKey = 'merchant_id';
    public $incrementing = false;
    protected $keyType = 'string';
    public $timestamps = false;

    protected $fillable = [
        'merchant_id',
        'gps_accuracy_m',
        'last_updated_at',
    ];

    protected function casts(): array
    {
        return [
            'gps_accuracy_m' => 'float',
            'last_updated_at' => 'datetime',
        ];
    }

    public function merchant(): BelongsTo
    {
        return $this->belongsTo(MerchantProfile::class, 'merchant_id');
    }

    /**
     * Update atau insert lokasi koordinat spasial PostGIS untuk merchant.
     */
    public static function updateCoordinates(string $merchantId, float $latitude, float $longitude, float $accuracyM, ?string $recordedAt = null): void
    {
        $timestamp = $recordedAt ? date('Y-m-d H:i:sP', strtotime($recordedAt)) : now()->toIso8601String();

        DB::statement('
            INSERT INTO merchant_locations (merchant_id, current_location, gps_accuracy_m, last_updated_at)
            VALUES (?, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?, ?)
            ON CONFLICT (merchant_id) DO UPDATE SET
                current_location = EXCLUDED.current_location,
                gps_accuracy_m = EXCLUDED.gps_accuracy_m,
                last_updated_at = EXCLUDED.last_updated_at
        ', [
            $merchantId,
            $longitude,
            $latitude,
            $accuracyM,
            $timestamp,
        ]);
    }
}

