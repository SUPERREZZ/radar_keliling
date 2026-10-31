<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PublicMerchantResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'merchant_id' => $this->id,
            'business_name' => $this->business_name,
            'description' => $this->description,
            'profile_photo_url' => $this->profile_photo_url,
            'average_rating' => (float) ($this->average_rating ?? 0.0),
            'total_reviews' => (int) ($this->total_reviews ?? 0),
            'is_selling' => (bool) $this->is_selling,
        ];
    }
}

