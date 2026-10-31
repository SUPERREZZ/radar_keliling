<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Call extends Model
{
    use HasFactory, HasUuids;

    public const STATUS_PENDING = 'pending';
    public const STATUS_ACCEPTED = 'accepted';
    public const STATUS_ANSWERED = 'accepted';
    public const STATUS_UNANSWERED = 'unanswered';
    public const STATUS_CANCELLED = 'cancelled';
    public const STATUS_COMPLETED = 'completed';
    public const STATUS_EXPIRED = 'expired';

    public $timestamps = false;

    protected $fillable = [
        'buyer_id',
        'merchant_id',
        'status',
        'location_consent',
        'consented_at',
        'location_expires_at',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'location_consent' => 'boolean',
            'consented_at' => 'datetime',
            'location_expires_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    public function buyer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'buyer_id');
    }

    public function merchant(): BelongsTo
    {
        return $this->belongsTo(MerchantProfile::class, 'merchant_id');
    }

    public function review(): HasOne
    {
        return $this->hasOne(Review::class, 'call_id');
    }

    public function getHasReviewAttribute(): bool
    {
        return $this->relationLoaded('review')
            ? $this->review !== null
            : $this->review()->exists();
    }
}

