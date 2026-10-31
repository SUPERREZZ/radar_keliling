<?php

namespace App\Http\Controllers\Api\V1\Merchant;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\MenuPhotoResource;
use App\Http\Resources\MenuResource;
use App\Models\Menu;
use App\Models\MenuPhoto;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Storage;

class MenuController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $profile = $request->user()->merchantProfile;

        if (! $profile) {
            throw new ApiException('MERCHANT_PROFILE_NOT_FOUND', 'Profil pedagang belum dibuat.', 404);
        }

        $menus = $profile->menus()->with('photos')->orderBy('created_at', 'desc')->get();

        return MenuResource::collection($menus);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $profile = $request->user()->merchantProfile;
        $menu = $profile->menus()->with('photos')->findOrFail($id);

        return (new MenuResource($menu))->response()->setStatusCode(200);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:1000'],
            'price' => ['required', 'numeric', 'min:0'],
            'is_available' => ['nullable', 'boolean'],
        ]);

        $profile = $request->user()->merchantProfile;

        $menu = $profile->menus()->create([
            'name' => trim($validated['name']),
            'description' => $validated['description'] ?? null,
            'price' => $validated['price'],
            'is_available' => $validated['is_available'] ?? true,
        ]);

        return (new MenuResource($menu->load('photos')))->response()->setStatusCode(201);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:100'],
            'description' => ['nullable', 'string', 'max:1000'],
            'price' => ['sometimes', 'required', 'numeric', 'min:0'],
            'is_available' => ['sometimes', 'required', 'boolean'],
        ]);

        $profile = $request->user()->merchantProfile;
        $menu = $profile->menus()->findOrFail($id);

        $menu->update($validated);

        return (new MenuResource($menu->load('photos')))->response()->setStatusCode(200);
    }

    public function destroy(Request $request, string $id): Response
    {
        $profile = $request->user()->merchantProfile;
        $menu = $profile->menus()->with('photos')->findOrFail($id);

        foreach ($menu->photos as $photo) {
            if ($photo->storage_path && Storage::disk('public')->exists($photo->storage_path)) {
                Storage::disk('public')->delete($photo->storage_path);
            }
        }

        $menu->delete();

        return response()->noContent();
    }

    public function uploadPhoto(Request $request, string $id): JsonResponse
    {
        $request->validate([
            'photo' => ['required', 'file', 'image', 'mimes:jpeg,jpg,png,webp', 'max:2048'],
        ]);

        $profile = $request->user()->merchantProfile;
        $menu = $profile->menus()->findOrFail($id);

        if ($menu->photos()->count() >= 5) {
            throw new ApiException('MAX_PHOTOS_EXCEEDED', 'Maksimal 5 foto per menu.', 422);
        }

        $path = $request->file('photo')->store('menus', 'public');

        $photo = $menu->photos()->create([
            'storage_path' => $path,
        ]);

        return (new MenuPhotoResource($photo))->response()->setStatusCode(201);
    }

    public function deletePhoto(Request $request, string $id): Response
    {
        $profile = $request->user()->merchantProfile;

        $photo = MenuPhoto::whereHas('menu', fn ($q) => $q->where('merchant_id', $profile->id))
            ->findOrFail($id);

        if ($photo->storage_path && Storage::disk('public')->exists($photo->storage_path)) {
            Storage::disk('public')->delete($photo->storage_path);
        }

        $photo->delete();

        return response()->noContent();
    }
}

