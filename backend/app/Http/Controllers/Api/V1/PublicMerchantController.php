<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\MenuResource;
use App\Http\Resources\PublicMerchantResource;
use App\Models\MerchantProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class PublicMerchantController extends Controller
{
    public function show(string $id): PublicMerchantResource
    {
        $merchant = MerchantProfile::findOrFail($id);

        return new PublicMerchantResource($merchant);
    }

    public function menus(string $id): AnonymousResourceCollection
    {
        $merchant = MerchantProfile::findOrFail($id);
        $menus = $merchant->menus()->with('photos')->where('is_available', true)->get();

        return MenuResource::collection($menus);
    }

    public function rating(string $id): JsonResponse
    {
        $merchant = MerchantProfile::findOrFail($id);

        $visibleReviews = $merchant->reviews()->where('moderation_status', 'visible');
        $totalReviews = $visibleReviews->count();
        $avgRating = $totalReviews > 0 ? round((float) $visibleReviews->avg('rating'), 1) : 0.0;

        return response()->json([
            'data' => [
                'merchant_id' => $merchant->id,
                'average_rating' => $avgRating,
                'total_reviews' => $totalReviews,
            ],
        ]);
    }
}

