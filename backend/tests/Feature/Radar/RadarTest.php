<?php

namespace Tests\Feature\Radar;

use App\Models\MerchantLocation;
use App\Models\MerchantProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RadarTest extends TestCase
{
    use RefreshDatabase;

    private function createBuyer(): array
    {
        $user = User::factory()->create(['role' => User::ROLE_BUYER]);
        $token = $user->createToken('mobile')->plainTextToken;

        return [$user, $token];
    }

    private function createMerchantWithLocation(string $name, float $lat, float $lng, bool $isSelling = true, ?string $updatedAt = null): MerchantProfile
    {
        $user = User::factory()->merchant()->create();
        $profile = MerchantProfile::create([
            'user_id' => $user->id,
            'business_name' => $name,
            'is_selling' => $isSelling,
        ]);

        MerchantLocation::updateCoordinates(
            $profile->id,
            $lat,
            $lng,
            10.0,
            $updatedAt ?? now()->toIso8601String()
        );

        return $profile;
    }

    public function test_buyer_can_find_nearby_active_merchants_with_distance_and_channels(): void
    {
        [, $token] = $this->createBuyer();

        // Titik buyer: -7.4700, 112.4300
        // Merchant terdekat (~150m): -7.4710, 112.4310
        $near = $this->createMerchantWithLocation('Bakso Pak Budi Dekat', -7.4710, 112.4310, true);

        // Merchant jauh (> 5 km): -7.4200, 112.4300
        $far = $this->createMerchantWithLocation('Sate Jauh', -7.4200, 112.4300, true);

        // Merchant terdekat tapi tidak jualan (is_selling = false)
        $notSelling = $this->createMerchantWithLocation('Siomay Tutup', -7.4705, 112.4305, false);

        $response = $this->withToken($token)->getJson('/api/v1/radar/merchants?latitude=-7.4700&longitude=112.4300&radius=3000');

        $response->assertOk()
            ->assertJsonPath('meta.radius_m', 3000)
            ->assertJsonStructure([
                'data' => [
                    '*' => [
                        'merchant_id',
                        'business_name',
                        'latitude',
                        'longitude',
                        'distance_m',
                        'gps_accuracy_m',
                        'last_updated_at',
                        'is_selling',
                    ],
                ],
                'meta' => [
                    'radius_m',
                    'websocket_channels',
                ],
            ]);

        $data = $response->json('data');
        $this->assertCount(1, $data);
        $this->assertEquals($near->id, $data[0]['merchant_id']);
        $this->assertEquals('Bakso Pak Budi Dekat', $data[0]['business_name']);
        $this->assertTrue($data[0]['distance_m'] < 300);

        // Verifikasi channel geohash Reverb
        $channels = $response->json('meta.websocket_channels');
        $this->assertNotEmpty($channels);
        $this->assertStringStartsWith('private-radar.', $channels[0]);
    }

    public function test_stale_merchant_location_is_not_returned(): void
    {
        [, $token] = $this->createBuyer();

        // Merchant aktif tapi lokasi diperbarui 60 detik yang lalu (stale > 30 detik)
        $this->createMerchantWithLocation(
            'Bakso Kadaluwarsa Lokasi',
            -7.4710,
            112.4310,
            true,
            now()->subSeconds(60)->toIso8601String()
        );

        $response = $this->withToken($token)->getJson('/api/v1/radar/merchants?latitude=-7.4700&longitude=112.4300');

        $response->assertOk();
        $this->assertEmpty($response->json('data'));
    }

    public function test_merchant_cannot_access_buyer_radar_endpoint(): void
    {
        $merchant = User::factory()->merchant()->create();
        $token = $merchant->createToken('mobile')->plainTextToken;

        $response = $this->withToken($token)->getJson('/api/v1/radar/merchants?latitude=-7.4700&longitude=112.4300');

        $response->assertStatus(403)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_radar_requires_valid_coordinates(): void
    {
        [, $token] = $this->createBuyer();

        $response = $this->withToken($token)->getJson('/api/v1/radar/merchants');

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_ERROR');
    }
}

