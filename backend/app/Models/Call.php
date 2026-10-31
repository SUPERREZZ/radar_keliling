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
    public const STATUS_ACCEPTED = 'accept';
    public const STATUS_ANSWERED = 'accept';
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

    public function scopeWithSpatialAndReview($query)
    {
        return $query
            ->leftJoin('merchant_locations as ml', 'ml.merchant_id', '=', 'calls.merchant_id')
            ->select('calls.*')
            ->selectRaw('
                ST_Y(calls.buyer_location::geometry) AS buyer_latitude,
                ST_X(calls.buyer_location::geometry) AS buyer_longitude,
                ROUND(ST_Distance(calls.buyer_location, ml.current_location)::numeric, 1) AS distance_m,
                EXISTS(SELECT 1 FROM reviews r WHERE r.call_id = calls.id) AS has_review_flag
            ');
    }

    public function getHasReviewAttribute(): bool
    {
        if (array_key_exists('has_review_flag', $this->attributes)) {
            return (bool) $this->attributes['has_review_flag'];
        }

        if (array_key_exists('has_review', $this->attributes)) {
            return (bool) $this->attributes['has_review'];
        }

        return $this->relationLoaded('review')
            ? $this->review !== null
            : $this->review()->exists();
    }
}

