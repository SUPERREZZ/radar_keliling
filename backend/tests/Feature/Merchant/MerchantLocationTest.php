<?php

namespace Tests\Feature\Merchant;

use App\Events\MerchantLocationUpdated;
use App\Events\MerchantSellingStatusChanged;
use App\Models\MerchantProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class MerchantLocationTest extends TestCase
{
    use RefreshDatabase;

    private function createMerchant(): array
    {
        $user = User::factory()->merchant()->create();
        $token = $user->createToken('mobile')->plainTextToken;
        $profile = MerchantProfile::create([
            'user_id' => $user->id,
            'business_name' => 'Soto Ayam Lamongan',
            'is_selling' => false,
        ]);

        return [$user, $token, $profile];
    }

    public function test_merchant_can_start_and_stop_selling(): void
    {
        Event::fake([MerchantSellingStatusChanged::class]);
        [, $token, $profile] = $this->createMerchant();

        // Start selling
        $startResponse = $this->withToken($token)->postJson('/api/v1/merchant/selling/start');
        $startResponse->assertOk()
            ->assertJsonPath('data.is_selling', true);

        $this->assertTrue($profile->fresh()->is_selling);

        // Stop selling
        $stopResponse = $this->withToken($token)->postJson('/api/v1/merchant/selling/stop');
        $stopResponse->assertOk()
            ->assertJsonPath('data.is_selling', false);

        $this->assertFalse($profile->fresh()->is_selling);
    }

    public function test_merchant_can_update_gps_location_and_dispatches_broadcast(): void
    {
        Event::fake([MerchantLocationUpdated::class]);
        [, $token, $profile] = $this->createMerchant();

        $response = $this->withToken($token)->putJson('/api/v1/merchant/location', [
            'latitude' => -7.4712,
            'longitude' => 112.4315,
            'accuracy_m' => 12.5,
            'recorded_at' => '2026-10-31T10:00:00Z',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.message', 'Lokasi berhasil diperbarui.');

        // Verifikasi koordinat tersimpan di PostGIS
        $loc = DB::table('merchant_locations')
            ->selectRaw('ST_Y(current_location::geometry) as lat, ST_X(current_location::geometry) as lng, gps_accuracy_m')
            ->where('merchant_id', $profile->id)
            ->first();

        $this->assertNotNull($loc);
        $this->assertEqualsWithDelta(-7.4712, $loc->lat, 0.0001);
        $this->assertEqualsWithDelta(112.4315, $loc->lng, 0.0001);
        $this->assertEquals(12.5, $loc->gps_accuracy_m);

        // Verifikasi Event Broadcasting ter-dispatch
        Event::assertDispatched(MerchantLocationUpdated::class, function ($event) use ($profile) {
            return $event->merchantId === $profile->id
                && $event->businessName === 'Soto Ayam Lamongan'
                && abs($event->latitude - (-7.4712)) < 0.0001
                && strlen($event->geohash) === 4;
        });
    }

    public function test_update_location_validation_fails_on_invalid_coordinates(): void
    {
        [, $token] = $this->createMerchant();

        $response = $this->withToken($token)->putJson('/api/v1/merchant/location', [
            'latitude' => 105.0, // Invalid latitude > 90
            'longitude' => 112.0,
            'accuracy_m' => -5.0, // Negative accuracy
        ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_ERROR');
    }

    public function test_buyer_cannot_update_merchant_location(): void
    {
        $buyer = User::factory()->create(['role' => User::ROLE_BUYER]);
        $token = $buyer->createToken('mobile')->plainTextToken;

        $response = $this->withToken($token)->putJson('/api/v1/merchant/location', [
            'latitude' => -7.47,
            'longitude' => 112.43,
            'accuracy_m' => 10,
        ]);

        $response->assertStatus(403)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_location_update_calculates_5m_movement_accurately(): void
    {
        [, $token] = $this->createMerchant();

        // Titik awal
        $initial = $this->withToken($token)->putJson('/api/v1/merchant/location', [
            'latitude' => -7.260000,
            'longitude' => 112.750000,
            'accuracy_m' => 5.0,
        ]);
        $initial->assertOk()
            ->assertJsonPath('data.distance_moved_m', null)
            ->assertJsonPath('data.has_moved_5m', true);

        // Bergeser hanya ~2 meter (di bawah threshold 5 meter)
        $smallMove = $this->withToken($token)->putJson('/api/v1/merchant/location', [
            'latitude' => -7.260018,
            'longitude' => 112.750000,
            'accuracy_m' => 5.0,
        ]);
        $smallMove->assertOk();
        $this->assertLessThan(5.0, (float) $smallMove->json('data.distance_moved_m'));
        $this->assertFalse($smallMove->json('data.has_moved_5m'));

        // Bergeser ~15 meter (melebihi threshold 5 meter)
        $bigMove = $this->withToken($token)->putJson('/api/v1/merchant/location', [
            'latitude' => -7.260150,
            'longitude' => 112.750000,
            'accuracy_m' => 5.0,
        ]);
        $bigMove->assertOk();
        $this->assertGreaterThanOrEqual(5.0, (float) $bigMove->json('data.distance_moved_m'));
        $this->assertTrue($bigMove->json('data.has_moved_5m'));
    }
}

