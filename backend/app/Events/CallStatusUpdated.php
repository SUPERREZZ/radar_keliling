<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class CallStatusUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public readonly string $callId,
        public readonly string $status,
        public readonly ?string $merchantId = null,
    ) {
    }

    public function broadcastOn(): array
    {
        $channels = [
            new PrivateChannel("call.{$this->callId}"),
        ];

        if ($this->merchantId) {
            $channels[] = new PrivateChannel("merchant.{$this->merchantId}");
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'CallStatusUpdated';
    }

    public function broadcastWith(): array
    {
        return [
            'call_id' => $this->callId,
            'status' => $this->status,
        ];
    }
}

