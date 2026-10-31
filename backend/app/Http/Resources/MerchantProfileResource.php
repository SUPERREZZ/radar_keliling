<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MerchantProfileResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'business_name' => $this->business_name,
            'description' => $this->description,
            'profile_photo_url' => $this->profile_photo_url,
            'is_selling' => (bool) $this->is_selling,
        ];
    }
}

