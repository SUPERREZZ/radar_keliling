<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PublicMerchantResource;
use App\Models\MerchantProfile;
use Illuminate\Http\JsonResponse;

class PublicMerchantController extends Controller
{
    public function show(string $id): PublicMerchantResource
    {
        $merchant = MerchantProfile::findOrFail($id);

        return new PublicMerchantResource($merchant);
    }

    public function rating(string $id): JsonResponse
    {
        $merchant = MerchantProfile::findOrFail($id);

        return response()->json([
            'data' => [
                'merchant_id' => $merchant->id,
                'average_rating' => (float) ($merchant->average_rating ?? 0.0),
                'total_reviews' => (int) ($merchant->total_reviews ?? 0),
            ],
        ]);
    }
}

