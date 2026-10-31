<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CallResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'merchant_id' => $this->merchant_id,
            'buyer_id' => $this->buyer_id,
            'status' => $this->status,
            'location_consent' => (bool) $this->location_consent,
            'created_at' => $this->created_at?->toIso8601String(),
            'has_review' => (bool) $this->has_review,
        ];
    }
}

