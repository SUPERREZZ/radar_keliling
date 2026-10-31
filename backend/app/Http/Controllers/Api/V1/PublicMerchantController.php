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
        $merchant = MerchantProfile::withCount([
            'reviews as total_reviews' => fn ($q) => $q->where('moderation_status', 'visible'),
        ])->withAvg([
            'reviews as average_rating' => fn ($q) => $q->where('moderation_status', 'visible'),
        ], 'rating')->findOrFail($id);

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
        $merchant = MerchantProfile::withCount([
            'reviews as total_reviews' => fn ($q) => $q->where('moderation_status', 'visible'),
        ])->withAvg([
            'reviews as average_rating' => fn ($q) => $q->where('moderation_status', 'visible'),
        ], 'rating')->findOrFail($id);

        return response()->json([
            'data' => [
                'merchant_id' => $merchant->id,
                'average_rating' => $merchant->average_rating,
                'total_reviews' => $merchant->total_reviews,
            ],
        ]);
    }

    public function reviews(Request $request, string $id): JsonResponse
    {
        $merchant = MerchantProfile::findOrFail($id);
        $reviews = $merchant->reviews()
            ->with('buyer:id,email')
            ->where('moderation_status', 'visible')
            ->orderBy('created_at', 'desc')
            ->limit(50)
            ->get();

        return response()->json([
            'data' => $reviews->map(fn ($r) => [
                'id' => $r->id,
                'call_id' => $r->call_id,
                'rating' => (int) $r->rating,
                'review_text' => $r->review_text,
                'buyer_name' => $r->buyer ? explode('@', $r->buyer->email)[0] : 'Pembeli',
                'created_at' => $r->created_at?->toIso8601String(),
            ]),
        ]);
    }
}
