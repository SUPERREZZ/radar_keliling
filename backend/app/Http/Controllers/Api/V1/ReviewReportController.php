<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Review;
use App\Models\ReviewReport;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReviewReportController extends Controller
{
    public function store(Request $request, string $id): JsonResponse
    {
        $review = Review::findOrFail($id);

        $validated = $request->validate([
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $report = ReviewReport::create([
            'review_id' => $review->id,
            'reporter_id' => $request->user()->id,
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

    public function adminIndex(): JsonResponse
    {
        $reports = ReviewReport::orderBy('created_at', 'desc')->get();

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

