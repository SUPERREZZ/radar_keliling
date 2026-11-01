<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\CallStatusUpdated;
use App\Events\IncomingCall;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\CallResource;
use App\Models\Call;
use App\Models\MerchantProfile;
use App\Services\FcmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class CallController extends Controller
{
    public function __construct(
        private readonly FcmService $fcmService
    ) {}

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

        // Pre-populate spatial & review attributes to avoid extra DB queries in CallResource
        $call->setRawAttributes(array_merge($call->getAttributes(), [
            'buyer_latitude' => $validated['share_location'] ? $bLat : null,
            'buyer_longitude' => $validated['share_location'] ? $bLng : null,
            'distance_m' => $validated['share_location'] ? $distanceM : null,
            'has_review_flag' => false,
        ]));

        // Broadcast event real-time ke pedagang via WebSocket Reverb
        try {
            broadcast(new IncomingCall(
                merchantId: $merchant->id,
                callId: $call->id,
                buyerLatitude: $validated['share_location'] ? $bLat : null,
                buyerLongitude: $validated['share_location'] ? $bLng : null,
                locationShared: (bool) $validated['share_location']
            ));
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Reverb broadcast failed on IncomingCall: '.$e->getMessage());
        }

        // Kirim Push Notification FCM ke perangkat pedagang (jika FCM diaktifkan)
        if ($merchant->user_id) {
            $this->fcmService->sendToUser(
                userId: (string) $merchant->user_id,
                title: 'Panggilan Pembeli Baru!',
                body: sprintf('Ada pembeli di sekitar Anda (~%.0f meter) yang memanggil dagangan Anda.', $distanceM),
                data: [
                    'type' => 'incoming_call',
                    'call_id' => (string) $call->id,
                    'merchant_id' => (string) $merchant->id,
                    'buyer_latitude' => $validated['share_location'] ? (string) $bLat : '',
                    'buyer_longitude' => $validated['share_location'] ? (string) $bLng : '',
                    'location_shared' => $validated['share_location'] ? '1' : '0',
                    'distance_m' => (string) $distanceM,
                ]
            );
        }

        return (new CallResource($call))->response()->setStatusCode(201);
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $request->user();

        $query = Call::query()->withSpatialAndReview();

        if ($user->isMerchant()) {
            $merchantId = $user->merchantProfile?->id;
            if (! $merchantId) {
                return CallResource::collection(collect());
            }
            $query->where('calls.merchant_id', $merchantId);
        } elseif ($user->isAdmin()) {
            if ($request->filled('merchant_id')) {
                $query->where('calls.merchant_id', $request->query('merchant_id'));
            }
            if ($request->filled('buyer_id')) {
                $query->where('calls.buyer_id', $request->query('buyer_id'));
            }
        } else {
            $query->where('calls.buyer_id', $user->id);
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
                $query->orderByRaw('ST_Distance(calls.buyer_location, ml.current_location) ASC NULLS LAST, calls.created_at DESC');
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

        $limit = min(max((int) $request->query('limit', 100), 1), 200);

        return CallResource::collection($query->limit($limit)->get());
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $call = Call::withSpatialAndReview()->where('calls.id', $id)->firstOrFail();

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
        $call = Call::withSpatialAndReview()->where('calls.id', $id)->firstOrFail();

        if ((string) $call->merchant_id !== (string) $user->merchantProfile?->id && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya pedagang yang dipanggil yang dapat menerima panggilan.', 403);
        }

        if ($call->status !== Call::STATUS_PENDING) {
            throw new ApiException('INVALID_CALL_STATE', 'Panggilan tidak dapat diterima karena status saat ini bukan pending.', 400);
        }

        $call->update(['status' => Call::STATUS_ACCEPTED]);
        $call->status = Call::STATUS_ACCEPTED;

        try {
            broadcast(new CallStatusUpdated($call->id, Call::STATUS_ACCEPTED, $call->merchant_id));
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Reverb broadcast failed on answer: '.$e->getMessage());
        }

        $this->fcmService->sendToUser(
            userId: (string) $call->buyer_id,
            title: 'Panggilan Diterima!',
            body: 'Pedagang telah menerima panggilan Anda dan sedang menuju lokasi.',
            data: [
                'type' => 'call_status_updated',
                'call_id' => (string) $call->id,
                'status' => Call::STATUS_ACCEPTED,
            ]
        );

        return (new CallResource($call))->response()->setStatusCode(200);
    }

    public function accept(Request $request, string $id): JsonResponse
    {
        return $this->answer($request, $id);
    }

    public function complete(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $call = Call::withSpatialAndReview()->where('calls.id', $id)->firstOrFail();

        if ((string) $call->merchant_id !== (string) $user->merchantProfile?->id && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya pedagang yang dipanggil yang dapat menyelesaikan transaksi panggilan.', 403);
        }

        if (! in_array($call->status, [Call::STATUS_PENDING, Call::STATUS_ACCEPTED, 'accept', 'answered'], true)) {
            throw new ApiException('INVALID_CALL_STATE', 'Panggilan tidak dapat diselesaikan dari status saat ini.', 400);
        }

        $call->update(['status' => Call::STATUS_COMPLETED]);
        $call->status = Call::STATUS_COMPLETED;

        try {
            broadcast(new CallStatusUpdated($call->id, Call::STATUS_COMPLETED, $call->merchant_id));
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Reverb broadcast failed on complete: '.$e->getMessage());
        }

        $this->fcmService->sendToUser(
            userId: (string) $call->buyer_id,
            title: 'Transaksi Selesai',
            body: 'Terima kasih! Jangan lupa berikan ulasan untuk pedagang.',
            data: [
                'type' => 'call_status_updated',
                'call_id' => (string) $call->id,
                'status' => Call::STATUS_COMPLETED,
            ]
        );

        return (new CallResource($call))->response()->setStatusCode(200);
    }

    public function unanswered(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $call = Call::withSpatialAndReview()->where('calls.id', $id)->firstOrFail();

        if ((string) $call->merchant_id !== (string) $user->merchantProfile?->id && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya pedagang yang dipanggil yang dapat menolak panggilan.', 403);
        }

        if ($call->status !== Call::STATUS_PENDING) {
            throw new ApiException('INVALID_CALL_STATE', 'Hanya panggilan berstatus pending yang dapat ditolak.', 400);
        }

        $call->update(['status' => Call::STATUS_UNANSWERED]);
        $call->status = Call::STATUS_UNANSWERED;

        try {
            broadcast(new CallStatusUpdated($call->id, Call::STATUS_UNANSWERED, $call->merchant_id));
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Reverb broadcast failed on unanswered: '.$e->getMessage());
        }

        $this->fcmService->sendToUser(
            userId: (string) $call->buyer_id,
            title: 'Panggilan Belum Terjawab',
            body: 'Maaf, pedagang sedang sibuk atau belum dapat menerima panggilan Anda.',
            data: [
                'type' => 'call_status_updated',
                'call_id' => (string) $call->id,
                'status' => Call::STATUS_UNANSWERED,
            ]
        );

        return (new CallResource($call))->response()->setStatusCode(200);
    }

    public function cancel(Request $request, string $id): JsonResponse
    {
        $user = $request->user();
        $call = Call::withSpatialAndReview()->where('calls.id', $id)->firstOrFail();

        if ((string) $call->buyer_id !== (string) $user->id && ! $user->isAdmin()) {
            throw new ApiException('FORBIDDEN', 'Hanya pembeli pemanggil yang dapat membatalkan panggilan.', 403);
        }

        if ($call->status !== Call::STATUS_PENDING) {
            throw new ApiException('INVALID_CALL_STATE', 'Hanya panggilan berstatus pending yang dapat dibatalkan.', 400);
        }

        $call->update(['status' => Call::STATUS_CANCELLED]);
        $call->status = Call::STATUS_CANCELLED;

        try {
            broadcast(new CallStatusUpdated($call->id, Call::STATUS_CANCELLED, $call->merchant_id));
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('Reverb broadcast failed on cancel: '.$e->getMessage());
        }

        $merchant = MerchantProfile::find($call->merchant_id);
        if ($merchant?->user_id) {
            $this->fcmService->sendToUser(
                userId: (string) $merchant->user_id,
                title: 'Panggilan Dibatalkan',
                body: 'Pembeli telah membatalkan panggilan.',
                data: [
                    'type' => 'call_status_updated',
                    'call_id' => (string) $call->id,
                    'status' => Call::STATUS_CANCELLED,
                ]
            );
        }

        return (new CallResource($call))->response()->setStatusCode(200);
    }
}
