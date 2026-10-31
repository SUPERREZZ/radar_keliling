<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\CallStatusUpdated;
use App\Events\IncomingCall;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\CallResource;
use App\Models\Call;
use App\Models\MerchantProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class CallController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isBuyer() && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya pembeli yang dapat melakukan panggilan ke pedagang.', 403);
        }

        $validated = $request->validate([
            'merchant_id' => ['required', 'uuid', 'exists:merchant_profiles,id'],
            'share_location' => ['required', 'boolean'],
            'buyer_latitude' => ['required', 'numeric', 'between:-90,90'],
            'buyer_longitude' => ['required', 'numeric', 'between:-180,180'],
            'gps_accuracy_m' => ['required', 'numeric', 'min:0'],
        ]);

        // Aturan: Akurasi GPS harus <= 50 meter
        if ((float) $validated['gps_accuracy_m'] > 50.0) {
            throw new ApiException('GPS_ACCURACY_INSUFFICIENT', 'Akurasi GPS tidak mencukupi (harus <= 50 meter).', 400);
        }

        $merchant = MerchantProfile::with('location')->findOrFail($validated['merchant_id']);

        // Aturan: Pedagang harus sedang aktif berjualan
        if (! $merchant->is_selling) {
            throw new ApiException('MERCHANT_NOT_SELLING', 'Pedagang sedang tidak aktif berjualan.', 400);
        }

        // Aturan: Rate limit panggilan maks 2 panggilan / 60 detik per pasangan buyer-merchant
        $recentCallsCount = Call::where('buyer_id', $user->id)
            ->where('merchant_id', $merchant->id)
            ->where('created_at', '>=', now()->subSeconds(60))
            ->count();

        if ($recentCallsCount >= 2) {
            throw new ApiException('CALL_RATE_LIMITED', 'Terlalu banyak panggilan ke pedagang ini. Silakan tunggu 60 detik.', 429);
        }

        // Aturan: Jarak pembeli ke pedagang maks 200 meter & cek lokasi tidak stale (Kalkulasi PostGIS)
        $bLat = (float) $validated['buyer_latitude'];
        $bLng = (float) $validated['buyer_longitude'];
        $staleLimit = (int) config('radar.stale_seconds', 30);

        $locResult = DB::selectOne("
            SELECT
                ROUND(ST_Distance(
                    ml.current_location,
                    ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
                )::numeric, 1) as distance_m,
                (ml.last_updated_at >= NOW() - (? || ' seconds')::interval) as is_fresh
            FROM merchant_locations ml
            WHERE ml.merchant_id = ?
        ", [$bLng, $bLat, $staleLimit, $merchant->id]);

        if (! $locResult) {
            throw new ApiException('MERCHANT_LOCATION_STALE', 'Lokasi pedagang belum tersedia.', 400);
        }

        if (! $locResult->is_fresh) {
            throw new ApiException('MERCHANT_LOCATION_STALE', 'Lokasi pedagang belum diperbarui dalam 30 detik terakhir.', 400);
        }

        $distanceM = (float) $locResult->distance_m;

        if ($distanceM > 200.0) {
            throw new ApiException('LOCATION_OUT_OF_RANGE', 'Pedagang berada di luar radius panggilan (maksimal 200 meter).', 400);
        }

        // Simpan data panggilan
        $call = new Call();
        $call->buyer_id = $user->id;
        $call->merchant_id = $merchant->id;
        $call->status = Call::STATUS_PENDING;
        $call->location_consent = (bool) $validated['share_location'];
        $call->consented_at = $validated['share_location'] ? now() : null;
        $call->location_expires_at = $validated['share_location'] ? now()->addMinutes(15) : null;
        $call->created_at = now();
        $call->save();

        if ($validated['share_location']) {
            DB::statement('
                UPDATE calls
                SET buyer_location = ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
                WHERE id = ?
            ', [$bLng, $bLat, $call->id]);
        }

        // Broadcast event real-time ke pedagang via WebSocket Reverb
        broadcast(new IncomingCall(
            merchantId: $merchant->id,
            callId: $call->id,
            buyerLatitude: $validated['share_location'] ? $bLat : null,
            buyerLongitude: $validated['share_location'] ? $bLng : null,
            locationShared: (bool) $validated['share_location']
        ));

        return (new CallResource($call))->response()->setStatusCode(201);
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $request->user();

        if ($user->isMerchant()) {
            $merchantId = $user->merchantProfile?->id;
            if (! $merchantId) {
                return CallResource::collection(collect());
            }
            $query = Call::where('calls.merchant_id', $merchantId);
        } elseif ($user->isAdmin()) {
            $query = Call::query();
            if ($request->filled('merchant_id')) {
                $query->where('calls.merchant_id', $request->query('merchant_id'));
            }
            if ($request->filled('buyer_id')) {
                $query->where('calls.buyer_id', $request->query('buyer_id'));
            }
        } else {
            $query = Call::where('calls.buyer_id', $user->id);
        }

        // Filter berdasarkan status panggilan (mendukung single atau comma-separated)
        if ($request->filled('status')) {
            $rawStatuses = array_filter(array_map('trim', explode(',', (string) $request->query('status'))));
            $expandedStatuses = [];
            foreach ($rawStatuses as $st) {
                if (in_array($st, ['accept', 'accepted', 'answered'], true)) {
                    $expandedStatuses = array_merge($expandedStatuses, ['accept', 'accepted', 'answered']);
                } else {
                    $expandedStatuses[] = $st;
                }
            }
            $query->whereIn('calls.status', array_unique($expandedStatuses));
        }

        // Sorting pesanan/panggilan berdasarkan parameter sort / sort_by
        $sort = strtolower((string) ($request->query('sort') ?? $request->query('sort_by') ?? 'latest'));
        $sortOrder = strtolower((string) $request->query('sort_order', 'desc')) === 'asc' ? 'asc' : 'desc';

        switch ($sort) {
            case 'priority':
            case 'pending_first':
                $query->orderByRaw("
                    CASE
                        WHEN calls.status = 'pending' THEN 0
                        WHEN calls.status IN ('accept', 'accepted', 'answered') THEN 1
                        WHEN calls.status = 'completed' THEN 2
                        ELSE 3
                    END ASC,
                    calls.created_at DESC
                ");
                break;

            case 'nearest':
            case 'distance':
                $query->leftJoin('merchant_locations as ml', 'ml.merchant_id', '=', 'calls.merchant_id')
                    ->select('calls.*')
                    ->selectRaw('ROUND(ST_Distance(calls.buyer_location, ml.current_location)::numeric, 1) as distance_m')
                    ->orderByRaw('ST_Distance(calls.buyer_location, ml.current_location) ASC NULLS LAST, calls.created_at DESC');
                break;

            case 'oldest':
            case 'asc':
                $query->orderBy('calls.created_at', 'asc');
                break;

            case 'status':
                $query->orderBy('calls.status', $sortOrder)->orderBy('calls.created_at', 'desc');
                break;

            case 'latest':
            case 'newest':
            case 'desc':
            default:
                $query->orderBy('calls.created_at', 'desc');
                break;
        }

        return CallResource::collection($query->get());
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $call = Call::findOrFail($id);

        $isOwner = (string) $call->buyer_id === (string) $user->id
            || (string) $call->merchant_id === (string) $user->merchantProfile?->id
            || $user->isAdmin();

        if (! $isOwner) {
            throw new ApiException('FORBIDDEN', 'Anda tidak memiliki akses ke data panggilan ini.', 403);
        }

        return (new CallResource($call))->response()->setStatusCode(200);
    }

    public function answer(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $call = Call::findOrFail($id);

        if ((string) $call->merchant_id !== (string) $user->merchantProfile?->id && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya pedagang yang dipanggil yang dapat menerima panggilan.', 403);
        }

        if ($call->status !== Call::STATUS_PENDING) {
            throw new ApiException('INVALID_CALL_STATE', 'Panggilan tidak dapat diterima karena status saat ini bukan pending.', 400);
        }

        $call->update(['status' => Call::STATUS_ACCEPTED]);

        broadcast(new CallStatusUpdated($call->id, Call::STATUS_ACCEPTED, $call->merchant_id));

        return (new CallResource($call->fresh()))->response()->setStatusCode(200);
    }

    public function accept(Request $request, string $id): JsonResponse
    {
        return $this->answer($request, $id);
    }

    public function complete(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $call = Call::findOrFail($id);

        if ((string) $call->merchant_id !== (string) $user->merchantProfile?->id && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya pedagang yang dipanggil yang dapat menyelesaikan transaksi panggilan.', 403);
        }

        if (! in_array($call->status, [Call::STATUS_PENDING, Call::STATUS_ACCEPTED, 'accept', 'answered'], true)) {
            throw new ApiException('INVALID_CALL_STATE', 'Panggilan tidak dapat diselesaikan dari status saat ini.', 400);
        }

        $call->update(['status' => Call::STATUS_COMPLETED]);

        broadcast(new CallStatusUpdated($call->id, Call::STATUS_COMPLETED, $call->merchant_id));

        return (new CallResource($call->fresh()))->response()->setStatusCode(200);
    }

    public function unanswered(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $call = Call::findOrFail($id);

        if ((string) $call->merchant_id !== (string) $user->merchantProfile?->id && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya pedagang yang dipanggil yang dapat menolak panggilan.', 403);
        }

        if ($call->status !== Call::STATUS_PENDING) {
            throw new ApiException('INVALID_CALL_STATE', 'Hanya panggilan berstatus pending yang dapat ditolak.', 400);
        }

        $call->update(['status' => Call::STATUS_UNANSWERED]);

        broadcast(new CallStatusUpdated($call->id, Call::STATUS_UNANSWERED, $call->merchant_id));

        return (new CallResource($call->fresh()))->response()->setStatusCode(200);
    }

    public function cancel(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $call = Call::findOrFail($id);

        if ((string) $call->buyer_id !== (string) $user->id && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya pembeli pemanggil yang dapat membatalkan panggilan.', 403);
        }

        if ($call->status !== Call::STATUS_PENDING) {
            throw new ApiException('INVALID_CALL_STATE', 'Hanya panggilan berstatus pending yang dapat dibatalkan.', 400);
        }

        $call->update(['status' => Call::STATUS_CANCELLED]);

        broadcast(new CallStatusUpdated($call->id, Call::STATUS_CANCELLED, $call->merchant_id));

        return (new CallResource($call->fresh()))->response()->setStatusCode(200);
    }
}
