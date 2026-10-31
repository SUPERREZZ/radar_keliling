<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\MenuResource;
use App\Http\Resources\PublicMerchantResource;
use App\Models\MerchantProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class PublicMerchantController extends Controller
{
    public function show(string $id): PublicMerchantResource
    {
        $merchant = MerchantProfile::findOrFail($id);

        return new PublicMerchantResource($merchant);
    }

    public function menus(Request $request, string $id): AnonymousResourceCollection
    {
        $merchant = MerchantProfile::findOrFail($id);
        $query = $merchant->menus()->with('photos')->where('is_available', true);

        if ($request->filled('search')) {
            $search = trim((string) $request->query('search'));
            $query->where(function ($q) use ($search) {
                $q->where('name', 'ILIKE', "%{$search}%")
                    ->orWhere('description', 'ILIKE', "%{$search}%");
            });
        }

        $sort = strtolower((string) ($request->query('sort') ?? $request->query('sort_by') ?? 'latest'));
        switch ($sort) {
            case 'price_asc':
                $query->orderBy('price', 'asc');
                break;
            case 'price_desc':
                $query->orderBy('price', 'desc');
                break;
            case 'name':
            case 'name_asc':
                $query->orderBy('name', 'asc');
                break;
            case 'name_desc':
                $query->orderBy('name', 'desc');
                break;
            default:
                $query->orderBy('created_at', 'desc');
                break;
        }

        return MenuResource::collection($query->get());
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
