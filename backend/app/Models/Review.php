<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Review extends Model
{
    use HasFactory, HasUuids;

    public const STATUS_VISIBLE = 'visible';
    public const STATUS_HIDDEN = 'hidden';

    protected $fillable = [
        'call_id',
        'buyer_id',
        'merchant_id',
        'rating',
        'review_text',
        'moderation_status',
    ];

    protected function casts(): array
    {
        return [
            'rating' => 'integer',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
        ];
    }

    public function call(): BelongsTo
    {
        return $this->belongsTo(Call::class);
    }

    public function buyer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'buyer_id');
    }

    public function merchant(): BelongsTo
    {
        return $this->belongsTo(MerchantProfile::class, 'merchant_id');
    }

    public function reports(): HasMany
    {
        return $this->hasMany(ReviewReport::class);
    }
}

