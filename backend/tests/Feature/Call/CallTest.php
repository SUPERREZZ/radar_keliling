<?php

namespace Tests\Feature\Call;

use App\Events\CallStatusUpdated;
use App\Events\IncomingCall;
use App\Models\Call;
use App\Models\MerchantLocation;
use App\Models\MerchantProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class CallTest extends TestCase
{
    use RefreshDatabase;

    private function createBuyer(): array
    {
        $user = User::factory()->create(['role' => User::ROLE_BUYER]);
        $token = $user->createToken('mobile')->plainTextToken;

        return [$user, $token];
    }

    private function createMerchant(float $lat = -7.4700, float $lng = 112.4300, bool $isSelling = true, ?string $updatedAt = null): array
    {
        $user = User::factory()->merchant()->create();
        $token = $user->createToken('mobile')->plainTextToken;
        $profile = MerchantProfile::create([
            'user_id' => $user->id,
            'business_name' => 'Bakso Cak Man',
            'is_selling' => $isSelling,
        ]);

        MerchantLocation::updateCoordinates(
            $profile->id,
            $lat,
            $lng,
            10.0,
            $updatedAt ?? now()->toIso8601String()
        );

        return [$user, $token, $profile];
    }

    public function test_buyer_can_call_nearby_merchant_successfully(): void
    {
        Event::fake([IncomingCall::class]);
        [, $buyerToken] = $this->createBuyer();
        // Merchant di -7.4700, 112.4300
        [, , $merchant] = $this->createMerchant(-7.4700, 112.4300);

        // Buyer di -7.4705, 112.4305 (~75m away, well within 200m)
        $response = $this->withToken($buyerToken)->postJson('/api/v1/calls', [
            'merchant_id' => $merchant->id,
            'share_location' => true,
            'buyer_latitude' => -7.4705,
            'buyer_longitude' => 112.4305,
            'gps_accuracy_m' => 12.0,
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonStructure(['data' => ['call_id', 'status', 'created_at']]);

        $callId = $response->json('data.call_id');
        $this->assertDatabaseHas('calls', [
            'id' => $callId,
            'status' => 'pending',
            'location_consent' => true,
        ]);

        Event::assertDispatched(IncomingCall::class, function ($event) use ($callId, $merchant) {
            return $event->callId === $callId
                && $event->merchantId === $merchant->id
                && $event->locationShared === true;
        });
    }

    public function test_call_fails_when_merchant_is_out_of_range(): void
    {
        [, $buyerToken] = $this->createBuyer();
        // Merchant di -7.4700, 112.4300
        [, , $merchant] = $this->createMerchant(-7.4700, 112.4300);

        // Buyer di -7.4750, 112.4350 (~750m away, exceeds 200m)
        $response = $this->withToken($buyerToken)->postJson('/api/v1/calls', [
            'merchant_id' => $merchant->id,
            'share_location' => true,
            'buyer_latitude' => -7.4750,
            'buyer_longitude' => 112.4350,
            'gps_accuracy_m' => 10.0,
        ]);

        $response->assertStatus(400)
            ->assertJsonPath('error.code', 'LOCATION_OUT_OF_RANGE');
    }

    public function test_call_fails_when_gps_accuracy_is_insufficient(): void
    {
        [, $buyerToken] = $this->createBuyer();
        [, , $merchant] = $this->createMerchant(-7.4700, 112.4300);

        $response = $this->withToken($buyerToken)->postJson('/api/v1/calls', [
            'merchant_id' => $merchant->id,
            'share_location' => true,
            'buyer_latitude' => -7.4705,
            'buyer_longitude' => 112.4305,
            'gps_accuracy_m' => 75.0, // Exceeds 50m
        ]);

        $response->assertStatus(400)
            ->assertJsonPath('error.code', 'GPS_ACCURACY_INSUFFICIENT');
    }

    public function test_call_fails_when_merchant_is_not_selling(): void
    {
        [, $buyerToken] = $this->createBuyer();
        [, , $merchant] = $this->createMerchant(-7.4700, 112.4300, false);

        $response = $this->withToken($buyerToken)->postJson('/api/v1/calls', [
            'merchant_id' => $merchant->id,
            'share_location' => true,
            'buyer_latitude' => -7.4705,
            'buyer_longitude' => 112.4305,
            'gps_accuracy_m' => 10.0,
        ]);

        $response->assertStatus(400)
            ->assertJsonPath('error.code', 'MERCHANT_NOT_SELLING');
    }

    public function test_call_fails_when_merchant_location_is_stale(): void
    {
        [, $buyerToken] = $this->createBuyer();
        [, , $merchant] = $this->createMerchant(-7.4700, 112.4300, true, now()->subSeconds(60)->toIso8601String());

        $response = $this->withToken($buyerToken)->postJson('/api/v1/calls', [
            'merchant_id' => $merchant->id,
            'share_location' => true,
            'buyer_latitude' => -7.4705,
            'buyer_longitude' => 112.4305,
            'gps_accuracy_m' => 10.0,
        ]);

        $response->assertStatus(400)
            ->assertJsonPath('error.code', 'MERCHANT_LOCATION_STALE');
    }

    public function test_call_rate_limiting_per_pair(): void
    {
        [,$buyerToken] = $this->createBuyer();
        [, , $merchant] = $this->createMerchant(-7.4700, 112.4300);

        $payload = [
            'merchant_id' => $merchant->id,
            'share_location' => true,
            'buyer_latitude' => -7.4705,
            'buyer_longitude' => 112.4305,
            'gps_accuracy_m' => 10.0,
        ];

        // Panggilan 1 (sukses)
        $this->withToken($buyerToken)->postJson('/api/v1/calls', $payload)->assertCreated();

        // Panggilan 2 (sukses)
        $this->withToken($buyerToken)->postJson('/api/v1/calls', $payload)->assertCreated();

        // Panggilan 3 (ditolak 429)
        $response = $this->withToken($buyerToken)->postJson('/api/v1/calls', $payload);
        $response->assertStatus(429)
            ->assertJsonPath('error.code', 'CALL_RATE_LIMITED');
    }

    public function test_merchant_can_answer_and_unanswer_call(): void
    {
        Event::fake([CallStatusUpdated::class]);
        [$buyer] = $this->createBuyer();
        [, $merchantToken, $merchant] = $this->createMerchant();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $merchant->id,
            'status' => 'pending',
            'location_consent' => true,
            'created_at' => now(),
        ]);

        // Answer / Accept
        $response = $this->withToken($merchantToken)->postJson("/api/v1/calls/{$call->id}/accept");
        $response->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        $this->assertEquals('accepted', $call->fresh()->status);
        Event::assertDispatched(CallStatusUpdated::class);

        // Complete (sudah tiba di lokasi)
        $completeResponse = $this->withToken($merchantToken)->postJson("/api/v1/calls/{$call->id}/complete");
        $completeResponse->assertOk()
            ->assertJsonPath('data.status', 'completed');
        $this->assertEquals('completed', $call->fresh()->status);
    }

    public function test_buyer_can_cancel_pending_call(): void
    {
        Event::fake([CallStatusUpdated::class]);
        [$buyer, $buyerToken] = $this->createBuyer();
        [, , $merchant] = $this->createMerchant();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $merchant->id,
            'status' => 'pending',
            'location_consent' => true,
            'created_at' => now(),
        ]);

        // Cancel
        $response = $this->withToken($buyerToken)->postJson("/api/v1/calls/{$call->id}/cancel");
        $response->assertOk()
            ->assertJsonPath('data.status', 'cancelled');

        $this->assertEquals('cancelled', $call->fresh()->status);
    }

    public function test_merchant_cannot_initiate_call(): void
    {
        [, $merchantToken] = $this->createMerchant();
        [, , $targetMerchant] = $this->createMerchant(-7.4700, 112.4300);

        $response = $this->withToken($merchantToken)->postJson('/api/v1/calls', [
            'merchant_id' => $targetMerchant->id,
            'share_location' => true,
            'buyer_latitude' => -7.4705,
            'buyer_longitude' => 112.4305,
            'gps_accuracy_m' => 10.0,
        ]);

        $response->assertStatus(403)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_unrelated_user_cannot_view_call_details(): void
    {
        [$buyer] = $this->createBuyer();
        [, $unrelatedToken] = $this->createBuyer();
        [, , $merchant] = $this->createMerchant();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $merchant->id,
            'status' => 'pending',
            'location_consent' => true,
            'created_at' => now(),
        ]);

        $this->withToken($unrelatedToken)->getJson("/api/v1/calls/{$call->id}")
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_cannot_accept_already_cancelled_call(): void
    {
        [$buyer] = $this->createBuyer();
        [, $merchantToken, $merchant] = $this->createMerchant();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $merchant->id,
            'status' => 'cancelled',
            'location_consent' => true,
            'created_at' => now(),
        ]);

        $response = $this->withToken($merchantToken)->postJson("/api/v1/calls/{$call->id}/accept");
        $response->assertStatus(400)
            ->assertJsonPath('error.code', 'INVALID_CALL_STATE');
    }

    public function test_other_merchant_cannot_accept_call(): void
    {
        [$buyer] = $this->createBuyer();
        [, , $merchantTarget] = $this->createMerchant();
        [, $otherMerchantToken] = $this->createMerchant();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $merchantTarget->id,
            'status' => 'pending',
            'location_consent' => true,
            'created_at' => now(),
        ]);

        $response = $this->withToken($otherMerchantToken)->postJson("/api/v1/calls/{$call->id}/accept");
        $response->assertStatus(403)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_merchant_can_mark_call_as_unanswered(): void
    {
        Event::fake([CallStatusUpdated::class]);
        [$buyer] = $this->createBuyer();
        [, $merchantToken, $merchant] = $this->createMerchant();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $merchant->id,
            'status' => 'pending',
            'location_consent' => true,
            'created_at' => now(),
        ]);

        $response = $this->withToken($merchantToken)->postJson("/api/v1/calls/{$call->id}/unanswered");
        $response->assertOk()
            ->assertJsonPath('data.status', 'unanswered');

        $this->assertEquals('unanswered', $call->fresh()->status);
        Event::assertDispatched(CallStatusUpdated::class);
    }

    public function test_merchant_can_filter_and_sort_calls_by_priority_status_and_distance(): void
    {
        [$buyer1] = $this->createBuyer();
        [$buyer2] = $this->createBuyer();
        [, $merchantToken, $merchant] = $this->createMerchant(-7.4700, 112.4300);

        // Call 1: completed (10 menit lalu)
        $callCompleted = Call::create([
            'buyer_id' => $buyer1->id,
            'merchant_id' => $merchant->id,
            'status' => Call::STATUS_COMPLETED,
            'location_consent' => false,
            'created_at' => now()->subMinutes(10),
        ]);

        // Call 2: pending, agak jauh (~150m, 5 menit lalu)
        $callPendingFar = Call::create([
            'buyer_id' => $buyer1->id,
            'merchant_id' => $merchant->id,
            'status' => Call::STATUS_PENDING,
            'location_consent' => true,
            'location_expires_at' => now()->addMinutes(15),
            'created_at' => now()->subMinutes(5),
        ]);
        DB::statement("UPDATE calls SET buyer_location = ST_SetSRID(ST_MakePoint(112.4310, -7.4710), 4326)::geography WHERE id = ?", [$callPendingFar->id]);

        // Call 3: pending, sangat dekat (~30m, 2 menit lalu)
        $callPendingNear = Call::create([
            'buyer_id' => $buyer2->id,
            'merchant_id' => $merchant->id,
            'status' => Call::STATUS_PENDING,
            'location_consent' => true,
            'location_expires_at' => now()->addMinutes(15),
            'created_at' => now()->subMinutes(2),
        ]);
        DB::statement("UPDATE calls SET buyer_location = ST_SetSRID(ST_MakePoint(112.4302, -7.4702), 4326)::geography WHERE id = ?", [$callPendingNear->id]);

        // 1. Filter status=pending
        $pendingRes = $this->withToken($merchantToken)->getJson('/api/v1/merchant/calls?status=pending');
        $pendingRes->assertOk()->assertJsonCount(2, 'data');

        // 2. Sort by priority (pending di atas completed)
        $priorityRes = $this->withToken($merchantToken)->getJson('/api/v1/merchant/calls?sort=priority');
        $priorityRes->assertOk()->assertJsonCount(3, 'data');
        $this->assertEquals('pending', $priorityRes->json('data.0.status'));
        $this->assertEquals('pending', $priorityRes->json('data.1.status'));
        $this->assertEquals('completed', $priorityRes->json('data.2.status'));

        // 3. Sort by nearest (jarak pembeli terdekat di urutan pertama)
        $nearestRes = $this->withToken($merchantToken)->getJson('/api/v1/merchant/calls?status=pending&sort=nearest');
        $nearestRes->assertOk()->assertJsonCount(2, 'data');
        $this->assertEquals($callPendingNear->id, $nearestRes->json('data.0.id'));
        $this->assertEquals($callPendingFar->id, $nearestRes->json('data.1.id'));
        $this->assertNotNull($nearestRes->json('data.0.buyer_latitude'));
        $this->assertNotNull($nearestRes->json('data.0.distance_m'));
    }

    public function test_expired_location_consent_hides_buyer_coordinates(): void
    {
        [$buyer] = $this->createBuyer();
        [, $merchantToken, $merchant] = $this->createMerchant(-7.4700, 112.4300);

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $merchant->id,
            'status' => Call::STATUS_ACCEPTED,
            'location_consent' => true,
            'location_expires_at' => now()->subMinutes(1), // Sudah lewat 15 menit
            'created_at' => now()->subMinutes(16),
        ]);
        DB::statement("UPDATE calls SET buyer_location = ST_SetSRID(ST_MakePoint(112.4302, -7.4702), 4326)::geography WHERE id = ?", [$call->id]);

        $res = $this->withToken($merchantToken)->getJson("/api/v1/calls/{$call->id}");
        $res->assertOk()
            ->assertJsonPath('data.buyer_latitude', null)
            ->assertJsonPath('data.buyer_longitude', null);
    }

    public function test_calls_list_has_no_n_plus_one_queries(): void
    {
        [$buyer] = $this->createBuyer();
        [, $merchantToken, $merchant] = $this->createMerchant(-7.4700, 112.4300);

        for ($i = 0; $i < 10; $i++) {
            $call = Call::create([
                'buyer_id' => $buyer->id,
                'merchant_id' => $merchant->id,
                'status' => Call::STATUS_PENDING,
                'location_consent' => true,
                'location_expires_at' => now()->addMinutes(15),
                'created_at' => now()->subSeconds($i),
            ]);
            DB::statement("UPDATE calls SET buyer_location = ST_SetSRID(ST_MakePoint(112.4302, -7.4702), 4326)::geography WHERE id = ?", [$call->id]);
        }

        DB::enableQueryLog();
        $res = $this->withToken($merchantToken)->getJson('/api/v1/merchant/calls');
        $queries = DB::getQueryLog();
        DB::disableQueryLog();

        $res->assertOk()->assertJsonCount(10, 'data');
        // Hanya 4 query: 1 sanctum token, 1 user, 1 merchant_profile, 1 calls list (tanpa N+1 per item)
        $this->assertLessThanOrEqual(5, count($queries));
    }
}

