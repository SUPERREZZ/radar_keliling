<?php

namespace Tests\Feature;

use App\Models\Call;
use App\Models\DemandLog;
use App\Models\Menu;
use App\Models\MerchantLocation;
use App\Models\MerchantProfile;
use App\Models\Review;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_database_seeder_populates_rich_initial_data(): void
    {
        $this->seed(DatabaseSeeder::class);

        // Verifikasi akun
        $this->assertDatabaseHas('users', ['email' => 'admin@radarkeliling.com', 'role' => User::ROLE_ADMIN]);
        $this->assertDatabaseHas('users', ['email' => 'buyer@radarkeliling.com', 'role' => User::ROLE_BUYER]);
        $this->assertDatabaseHas('users', ['email' => 'budi@radarkeliling.com', 'role' => User::ROLE_MERCHANT]);

        // Verifikasi merchant
        $this->assertGreaterThanOrEqual(5, MerchantProfile::count());
        $this->assertGreaterThanOrEqual(4, MerchantLocation::count());
        $this->assertGreaterThanOrEqual(10, Menu::count());

        // Verifikasi calls & reviews
        $this->assertGreaterThanOrEqual(2, Call::count());
        $this->assertGreaterThanOrEqual(2, Review::count());

        // Verifikasi demand logs
        $this->assertGreaterThanOrEqual(500, DemandLog::count());
    }
}

