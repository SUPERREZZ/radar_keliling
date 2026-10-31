<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class IncomingCall implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly string $merchantId,
        public readonly string $callId,
        public readonly ?float $buyerLatitude,
        public readonly ?float $buyerLongitude,
        public readonly bool $locationShared,
    ) {
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel("merchant.{$this->merchantId}"),
        ];
    }

    public function broadcastAs(): string
    {
        return 'IncomingCall';
    }

    public function broadcastWith(): array
    {
        return [
            'call_id' => $this->callId,
            'buyer_latitude' => $this->buyerLatitude,
            'buyer_longitude' => $this->buyerLongitude,
            'location_shared' => $this->locationShared,
        ];
    }
}

