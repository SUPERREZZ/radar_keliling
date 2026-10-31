<?php

namespace Tests\Feature\Call;

use App\Events\CallStatusUpdated;
use App\Events\IncomingCall;
use App\Models\Call;
use App\Models\MerchantLocation;
use App\Models\MerchantProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
}

