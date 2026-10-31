<?php

namespace App\Http\Controllers\Api\V1\Merchant;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\MenuPhotoResource;
use App\Http\Resources\MenuResource;
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

        $query = $profile->menus()->with('photos');

        // Filter ketersediaan menu (is_available=true/false/1/0)
        if ($request->filled('is_available')) {
            $isAvailable = filter_var($request->query('is_available'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
            if ($isAvailable !== null) {
                $query->where('is_available', $isAvailable);
            }
        }

        // Pencarian berdasarkan nama atau deskripsi menu
        if ($request->filled('search')) {
            $search = trim((string) $request->query('search'));
            $query->where(function ($q) use ($search) {
                $q->where('name', 'ILIKE', "%{$search}%")
                    ->orWhere('description', 'ILIKE', "%{$search}%");
            });
        }

        // Sorting menu
        $sort = strtolower((string) ($request->query('sort') ?? $request->query('sort_by') ?? 'latest'));
        $sortOrder = strtolower((string) $request->query('sort_order', 'desc')) === 'asc' ? 'asc' : 'desc';

        switch ($sort) {
            case 'price_asc':
                $query->orderBy('price', 'asc');
                break;
            case 'price_desc':
                $query->orderBy('price', 'desc');
                break;
            case 'price':
                $query->orderBy('price', $sortOrder);
                break;
            case 'name_asc':
                $query->orderBy('name', 'asc');
                break;
            case 'name_desc':
                $query->orderBy('name', 'desc');
                break;
            case 'name':
                $query->orderBy('name', $sortOrder);
                break;
            case 'available_first':
            case 'is_available':
                $query->orderBy('is_available', 'desc')->orderBy('created_at', 'desc');
                break;
            case 'oldest':
            case 'asc':
                $query->orderBy('created_at', 'asc');
                break;
            case 'latest':
            case 'newest':
            case 'created_at':
            default:
                $query->orderBy('created_at', $request->filled('sort_order') ? $sortOrder : 'desc');
                break;
        }

        return MenuResource::collection($query->get());
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

        if (! $profile) {
            throw new ApiException('MERCHANT_PROFILE_NOT_FOUND', 'Profil pedagang belum dibuat.', 404);
        }

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

    public function toggleAvailability(Request $request, string $id): JsonResponse
    {
        $profile = $request->user()->merchantProfile;
        $menu = $profile->menus()->findOrFail($id);

        $isAvailable = $request->has('is_available')
            ? (bool) $request->boolean('is_available')
            : ! $menu->is_available;

        $menu->update(['is_available' => $isAvailable]);

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
        $menu = $profile->menus()->withCount('photos')->findOrFail($id);

        if ($menu->photos_count >= 5) {
            throw new ApiException(
                'MAX_PHOTOS_EXCEEDED',
                'Maksimal 5 foto per item menu.',
                422
            );
        }

        $path = $request->file('photo')->store("menus/{$menu->id}", 'public');

        $photo = $menu->photos()->create([
            'storage_path' => $path,
        ]);

        return (new MenuPhotoResource($photo))->response()->setStatusCode(201);
    }

    public function deletePhoto(Request $request, string $id): Response
    {
        $profile = $request->user()->merchantProfile;

        $photo = MenuPhoto::where('id', $id)
            ->whereHas('menu', fn ($q) => $q->where('merchant_id', $profile->id))
            ->firstOrFail();

        if ($photo->storage_path && Storage::disk('public')->exists($photo->storage_path)) {
            Storage::disk('public')->delete($photo->storage_path);
        }

        $photo->delete();

        return response()->noContent();
    }
}
