<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\Review;
use App\Models\ReviewReport;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReviewReportController extends Controller
{
    public function store(Request $request, string $id): JsonResponse
    {
        $user = $request->user();

        if (! $user->isBuyer() && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya akun pembeli yang dapat melaporkan ulasan.', 403);
        }

        $review = Review::findOrFail($id);

        if (ReviewReport::where('review_id', $review->id)->where('reporter_id', $user->id)->exists()) {
            throw new ApiException('REPORT_ALREADY_EXISTS', 'Anda sudah pernah melaporkan ulasan ini sebelumnya.', 409);
        }

        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $report = ReviewReport::create([
            'review_id' => $review->id,
            'reporter_id' => $user->id,
            'reason' => $validated['reason'],
            'status' => ReviewReport::STATUS_PENDING,
        ]);

        return response()->json([
            'data' => [
                'id' => $report->id,
                'message' => 'Laporan berhasil dikirim.',
            ],
        ], 201);
    }

    public function adminIndex(Request $request): JsonResponse
    {
        $query = ReviewReport::query();

        if ($request->filled('status')) {
            $query->where('status', strtolower(trim((string) $request->query('status'))));
        }

        $sort = strtolower((string) ($request->query('sort') ?? 'latest'));
        if ($sort === 'oldest' || $sort === 'asc') {
            $query->orderBy('created_at', 'asc');
        } else {
            $query->orderBy('created_at', 'desc');
        }

        $limit = min(max((int) $request->query('limit', 100), 1), 200);
        $reports = $query->limit($limit)->get();

        return response()->json([
            'data' => $reports->map(fn (ReviewReport $report) => [
                'id' => $report->id,
                'review_id' => $report->review_id,
                'reporter_id' => $report->reporter_id,
                'reason' => $report->reason,
                'status' => $report->status,
                'created_at' => $report->created_at?->toIso8601String(),
            ]),
        ]);
    }
}
