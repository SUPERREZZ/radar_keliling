<?php

namespace App\Http\Controllers\Api\V1\Merchant;

use App\Http\Controllers\Controller;
use App\Http\Resources\MerchantProfileResource;
use App\Models\MerchantProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class MerchantProfileController extends Controller
{
    public function dashboard(Request $request): JsonResponse
    {
        $profile = MerchantProfile::firstOrCreate(
            ['user_id' => $request->user()->id],
            [
                'business_name' => 'Pedagang Baru',
                'description' => null,
                'is_selling' => false,
            ]
        );

        $stats = DB::selectOne("
            SELECT
                (SELECT COUNT(*) FROM calls WHERE merchant_id = ? AND status = 'pending') AS pending_calls,
                (SELECT COUNT(*) FROM calls WHERE merchant_id = ? AND status IN ('accept', 'accepted', 'answered')) AS active_calls,
                (SELECT COUNT(*) FROM calls WHERE merchant_id = ? AND status = 'completed' AND created_at >= CURRENT_DATE) AS completed_today,
                (SELECT COUNT(*) FROM calls WHERE merchant_id = ? AND status = 'completed') AS total_completed_calls,
                (SELECT COUNT(*) FROM menus WHERE merchant_id = ?) AS total_menus,
                (SELECT COUNT(*) FROM menus WHERE merchant_id = ? AND is_available = TRUE) AS available_menus,
                (SELECT COUNT(*) FROM reviews WHERE merchant_id = ? AND moderation_status = 'visible') AS total_reviews,
                COALESCE((SELECT ROUND(AVG(rating)::numeric, 1) FROM reviews WHERE merchant_id = ? AND moderation_status = 'visible'), 0.0) AS average_rating
        ", array_fill(0, 8, $profile->id));

        return response()->json([
            'data' => [
                'merchant_id' => $profile->id,
                'business_name' => $profile->business_name,
                'is_selling' => (bool) $profile->is_selling,
                'pending_calls' => (int) ($stats->pending_calls ?? 0),
                'active_calls' => (int) ($stats->active_calls ?? 0),
                'completed_today' => (int) ($stats->completed_today ?? 0),
                'total_completed_calls' => (int) ($stats->total_completed_calls ?? 0),
                'total_menus' => (int) ($stats->total_menus ?? 0),
                'available_menus' => (int) ($stats->available_menus ?? 0),
                'total_reviews' => (int) ($stats->total_reviews ?? 0),
                'average_rating' => (float) ($stats->average_rating ?? 0.0),
            ],
        ]);
    }

    public function show(Request $request): JsonResponse
    {
        $profile = MerchantProfile::firstOrCreate(
            ['user_id' => $request->user()->id],
            [
                'business_name' => 'Pedagang Baru',
                'description' => null,
                'is_selling' => false,
            ]
        );

        return (new MerchantProfileResource($profile))->response()->setStatusCode(200);
    }

    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'business_name' => ['required', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:1000'],
        ]);

        $profile = MerchantProfile::firstOrCreate(
            ['user_id' => $request->user()->id],
            [
                'business_name' => trim($validated['business_name']),
                'description' => $validated['description'] ?? null,
                'is_selling' => false,
            ]
        );

        $profile->update([
            'business_name' => trim($validated['business_name']),
            'description' => $validated['description'] ?? null,
        ]);

        return (new MerchantProfileResource($profile))->response()->setStatusCode(200);
    }

    public function uploadPhoto(Request $request): JsonResponse
    {
        $request->validate([
            'photo' => ['required', 'file', 'image', 'mimes:jpeg,jpg,png,webp', 'max:2048'],
        ]);

        $profile = MerchantProfile::firstOrCreate(
            ['user_id' => $request->user()->id],
            [
                'business_name' => 'Pedagang Baru',
                'description' => null,
                'is_selling' => false,
            ]
        );

        // Hapus foto profil lama jika ada di disk lokal
        if ($profile->profile_photo_path && Storage::disk('public')->exists($profile->profile_photo_path)) {
            Storage::disk('public')->delete($profile->profile_photo_path);
        }

        $path = $request->file('photo')->store('merchants/profiles', 'public');

        $profile->update([
            'profile_photo_path' => $path,
        ]);

        return response()->json([
            'data' => [
                'profile_photo_url' => $profile->profile_photo_url,
            ],
        ]);
    }
}
