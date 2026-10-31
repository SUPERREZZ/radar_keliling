<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Menu extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'merchant_id',
        'name',
        'description',
        'price',
        'is_available',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'float',
            'is_available' => 'boolean',
        ];
    }

    public function merchant(): BelongsTo
    {
        return $this->belongsTo(MerchantProfile::class, 'merchant_id');
    }

    public function photos(): HasMany
    {
        return $this->hasMany(MenuPhoto::class);
    }
}

