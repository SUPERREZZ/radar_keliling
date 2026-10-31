<?php

namespace App\Http\Controllers\Api\V1\Merchant;

use App\Http\Controllers\Controller;
use App\Http\Resources\MerchantProfileResource;
use App\Models\MerchantProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class MerchantProfileController extends Controller
{
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
