<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MerchantLocationUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly string $geohash,
        public readonly string $merchantId,
        public readonly string $businessName,
        public readonly float $latitude,
        public readonly float $longitude,
        public readonly float $gpsAccuracyM,
        public readonly string $lastUpdatedAt,
        public readonly bool $isSelling,
    ) {
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel("radar.{$this->geohash}"),
        ];
    }

    public function broadcastAs(): string
    {
        return 'MerchantLocationUpdated';
    }

    public function broadcastWith(): array
    {
        return [
            'merchant_id' => $this->merchantId,
            'business_name' => $this->businessName,
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,
            'gps_accuracy_m' => $this->gpsAccuracyM,
            'last_updated_at' => $this->lastUpdatedAt,
            'is_selling' => $this->isSelling,
        ];
    }
}

