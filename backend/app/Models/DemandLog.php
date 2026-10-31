<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class DemandLog extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $fillable = [
        'kategori_pencarian',
        'geom',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
        ];
    }

    public static function record(float $lat, float $lng, ?string $category = null): void
    {
        DB::statement('
            INSERT INTO demand_logs (kategori_pencarian, geom, created_at)
            VALUES (?, ST_SetSRID(ST_MakePoint(?, ?), 4326), NOW())
        ', [$category, $lng, $lat]);
    }
}

