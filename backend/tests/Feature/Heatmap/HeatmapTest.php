<?php

namespace Tests\Feature\Heatmap;

use App\Models\DemandLog;
use App\Models\MerchantLocation;
use App\Models\MerchantProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class HeatmapTest extends TestCase
{
    use RefreshDatabase;

    private function createMerchant(): array
    {
        $user = User::factory()->create([
            'email' => 'pedagang_hotspot@example.com',
            'role' => User::ROLE_MERCHANT,
            'email_verified' => true,
        ]);

        $profile = MerchantProfile::create([
            'user_id' => $user->id,
            'business_name' => 'Bakso Cak Budi',
            'description' => 'Bakso enak mantap',
            'is_selling' => true,
        ]);

        MerchantLocation::updateCoordinates(
            $profile->id,
            -7.2620,
            112.7480,
            10.0,
            now()->toIso8601String()
        );

        return [$user, $profile];
    }

    private function createBuyer(): User
    {
        return User::factory()->create([
            'email' => 'pembeli_hotspot@example.com',
            'role' => User::ROLE_BUYER,
            'email_verified' => true,
        ]);
    }

    public function test_can_retrieve_heatmap_clusters(): void
    {
        $currentHour = 14;

        // Buat demand log di jam 14
        for ($i = 0; $i < 5; $i++) {
            DB::statement("
                INSERT INTO demand_logs (kategori_pencarian, geom, created_at)
                VALUES ('bakso', ST_SetSRID(ST_MakePoint(112.7485, -7.2625), 4326), '2026-10-31 14:10:00')
            ");
        }

        $response = $this->getJson("/api/v1/heatmap?hour={$currentHour}");

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    ['latitude', 'longitude', 'weight', 'total_requests'],
                ],
                'meta' => ['hour', 'category', 'grid_size', 'total_hotspots'],
            ])
            ->assertJsonPath('meta.hour', 14)
            ->assertJsonPath('data.0.total_requests', 5);

        $this->assertEquals(1.0, (float) $response->json('data.0.weight'));
    }

    public function test_heatmap_filters_by_category(): void
    {
        // 5 titik bakso
        for ($i = 0; $i < 5; $i++) {
            DB::statement("
                INSERT INTO demand_logs (kategori_pencarian, geom, created_at)
                VALUES ('bakso', ST_SetSRID(ST_MakePoint(112.7485, -7.2625), 4326), '2026-10-31 12:00:00')
            ");
        }

        // 2 titik minuman
        for ($i = 0; $i < 2; $i++) {
            DB::statement("
                INSERT INTO demand_logs (kategori_pencarian, geom, created_at)
                VALUES ('minuman', ST_SetSRID(ST_MakePoint(112.7550, -7.2700), 4326), '2026-10-31 12:00:00')
            ");
        }

        $response = $this->getJson('/api/v1/heatmap?hour=12&category=bakso');

        $response->assertStatus(200)
            ->assertJsonPath('meta.total_hotspots', 1)
            ->assertJsonPath('data.0.total_requests', 5);
    }

    public function test_merchant_can_access_smart_buyer_hotspots(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();

        // Buat klaster demand dekat merchant
        for ($i = 0; $i < 8; $i++) {
            DB::statement("
                INSERT INTO demand_logs (kategori_pencarian, geom, created_at)
                VALUES ('bakso', ST_SetSRID(ST_MakePoint(112.7485, -7.2625), 4326), '2026-10-31 15:30:00')
            ");
        }

        $response = $this->actingAs($merchantUser)->getJson('/api/v1/merchant/radar/buyer-hotspots?hour=15');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    ['latitude', 'longitude', 'weight', 'total_requests', 'distance_m', 'recommendation'],
                ],
                'meta' => ['hour', 'total_recommendations'],
            ])
            ->assertJsonPath('data.0.total_requests', 8);

        $this->assertNotNull($response->json('data.0.distance_m'));
    }

    public function test_radar_merchants_logs_buyer_demand(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer = $this->createBuyer();

        $initialCount = DemandLog::count();

        $this->actingAs($buyer)->getJson('/api/v1/radar/merchants?latitude=-7.2620&longitude=112.7480&category=bakso')
            ->assertStatus(200);

        $this->assertEquals($initialCount + 1, DemandLog::count());

        $this->assertDatabaseHas('demand_logs', [
            'kategori_pencarian' => 'bakso',
        ]);
    }
}
