<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\Call;
use App\Models\Review;
use App\Models\ReviewReport;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReviewController extends Controller
{
    public function store(Request $request, string $id): JsonResponse
    {
        $user = $request->user();

        if (! $user->isBuyer() && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya pembeli yang dapat memberikan ulasan.', 403);
        }

        $call = Call::findOrFail($id);

        if ((string) $call->buyer_id !== (string) $user->id && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Anda hanya dapat memberikan ulasan untuk panggilan Anda sendiri.', 403);
        }

        $allowedStatuses = [
            'accept',
            Call::STATUS_ACCEPTED,
            Call::STATUS_COMPLETED,
            'answered',
        ];

        if (! in_array($call->status, $allowedStatuses, true)) {
            throw new ApiException('INVALID_CALL_STATE', 'Ulasan hanya dapat diberikan setelah panggilan diterima atau selesai.', 400);
        }

        if (Review::where('call_id', $call->id)->exists()) {
            throw new ApiException('REVIEW_ALREADY_EXISTS', 'Ulasan untuk panggilan ini sudah pernah diberikan.', 409);
        }

        $validated = $request->validate([
            'rating' => ['required', 'integer', 'between:1,5'],
            'review_text' => ['nullable', 'string', 'max:500'],
        ]);

        $review = Review::create([
            'call_id' => $call->id,
            'buyer_id' => $user->id,
            'merchant_id' => $call->merchant_id,
            'rating' => (int) $validated['rating'],
            'review_text' => $validated['review_text'] ?? null,
            'moderation_status' => Review::STATUS_VISIBLE,
        ]);

        return response()->json([
            'data' => [
                'id' => $review->id,
                'rating' => $review->rating,
                'created_at' => $review->created_at->toIso8601String(),
            ],
        ], 201);
    }

    public function adminIndex(Request $request): JsonResponse
    {
        $query = Review::query();

        if ($request->filled('status') || $request->filled('moderation_status')) {
            $status = strtolower((string) ($request->query('status') ?? $request->query('moderation_status')));
            $query->where('moderation_status', $status);
        }

        $sort = strtolower((string) ($request->query('sort') ?? 'latest'));
        switch ($sort) {
            case 'oldest':
                $query->orderBy('created_at', 'asc');
                break;
            case 'rating_asc':
                $query->orderBy('rating', 'asc')->orderBy('created_at', 'desc');
                break;
            case 'rating_desc':
                $query->orderBy('rating', 'desc')->orderBy('created_at', 'desc');
                break;
            default:
                $query->orderBy('created_at', 'desc');
                break;
        }

        $limit = min(max((int) $request->query('limit', 100), 1), 200);
        $reviews = $query->limit($limit)->get();

        return response()->json([
            'data' => $reviews->map(fn (Review $r) => [
                'id' => $r->id,
                'call_id' => $r->call_id,
                'merchant_id' => $r->merchant_id,
                'buyer_id' => $r->buyer_id,
                'rating' => $r->rating,
                'review_text' => $r->review_text,
                'moderation_status' => $r->moderation_status,
                'created_at' => $r->created_at?->toIso8601String(),
            ]),
        ]);
    }

    public function hide(string $id): JsonResponse
    {
        $review = Review::findOrFail($id);

        $review->update(['moderation_status' => Review::STATUS_HIDDEN]);

        ReviewReport::where('review_id', $review->id)
            ->where('status', ReviewReport::STATUS_PENDING)
            ->update(['status' => ReviewReport::STATUS_REVIEWED]);

        return response()->json([
            'data' => [
                'id' => $review->id,
                'moderation_status' => Review::STATUS_HIDDEN,
            ],
        ]);
    }

    public function unhide(string $id): JsonResponse
    {
        $review = Review::findOrFail($id);

        $review->update(['moderation_status' => Review::STATUS_VISIBLE]);

        return response()->json([
            'data' => [
                'id' => $review->id,
                'moderation_status' => Review::STATUS_VISIBLE,
            ],
        ]);
    }
}
