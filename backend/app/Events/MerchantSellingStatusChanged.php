<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MerchantSellingStatusChanged implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly ?string $geohash,
        public readonly string $merchantId,
        public readonly bool $isSelling,
    ) {
    }

    public function broadcastOn(): array
    {
        if (! $this->geohash) {
            return [];
        }

        return [
            new PrivateChannel("radar.{$this->geohash}"),
        ];
    }

    public function broadcastAs(): string
    {
        return 'MerchantSellingStatusChanged';
    }

    public function broadcastWith(): array
    {
        return [
            'merchant_id' => $this->merchantId,
            'is_selling' => $this->isSelling,
        ];
    }
}

