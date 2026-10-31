<?php

namespace Tests\Feature\Merchant;

use App\Models\MerchantProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class MerchantProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_merchant_can_view_own_profile(): void
    {
        $merchantUser = User::factory()->merchant()->create();
        $token = $merchantUser->createToken('mobile')->plainTextToken;

        MerchantProfile::create([
            'user_id' => $merchantUser->id,
            'business_name' => 'Bakso Pak Budi',
            'description' => 'Bakso enak dan murah.',
            'is_selling' => false,
        ]);

        $response = $this->withToken($token)->getJson('/api/v1/merchant/profile');

        $response->assertOk()
            ->assertJsonPath('data.business_name', 'Bakso Pak Budi')
            ->assertJsonPath('data.description', 'Bakso enak dan murah.')
            ->assertJsonPath('data.is_selling', false);
    }

    public function test_buyer_cannot_access_merchant_profile_endpoints(): void
    {
        $buyerUser = User::factory()->create(['role' => User::ROLE_BUYER]);
        $token = $buyerUser->createToken('mobile')->plainTextToken;

        $response = $this->withToken($token)->getJson('/api/v1/merchant/profile');

        $response->assertStatus(403)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_merchant_can_update_profile(): void
    {
        $merchantUser = User::factory()->merchant()->create();
        $token = $merchantUser->createToken('mobile')->plainTextToken;

        $response = $this->withToken($token)->putJson('/api/v1/merchant/profile', [
            'business_name' => 'Sate Ayam Madura Cak Sholeh',
            'description' => 'Bumbu kacang kental khas Madura.',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.business_name', 'Sate Ayam Madura Cak Sholeh')
            ->assertJsonPath('data.description', 'Bumbu kacang kental khas Madura.');

        $this->assertDatabaseHas('merchant_profiles', [
            'user_id' => $merchantUser->id,
            'business_name' => 'Sate Ayam Madura Cak Sholeh',
        ]);
    }

    public function test_merchant_can_upload_profile_photo(): void
    {
        Storage::fake('public');

        $merchantUser = User::factory()->merchant()->create();
        $token = $merchantUser->createToken('mobile')->plainTextToken;

        $file = UploadedFile::fake()->image('gerobak.jpg', 600, 600);

        $response = $this->withToken($token)->postJson('/api/v1/merchant/profile/photo', [
            'photo' => $file,
        ]);

        $response->assertOk()
            ->assertJsonStructure(['data' => ['profile_photo_url']]);

        $profile = MerchantProfile::where('user_id', $merchantUser->id)->firstOrFail();
        $this->assertNotNull($profile->profile_photo_path);
        Storage::disk('public')->assertExists($profile->profile_photo_path);
    }

    public function test_public_can_view_merchant_details_and_rating(): void
    {
        $merchantUser = User::factory()->merchant()->create();
        $buyerUser = User::factory()->create();
        $token = $buyerUser->createToken('mobile')->plainTextToken;

        $profile = MerchantProfile::create([
            'user_id' => $merchantUser->id,
            'business_name' => 'Siomay Bandung Asli',
            'description' => 'Bumbu kacang gurih pedas.',
            'is_selling' => true,
        ]);

        // GET /merchants/{id}
        $response = $this->withToken($token)->getJson("/api/v1/merchants/{$profile->id}");
        $response->assertOk()
            ->assertJsonPath('data.merchant_id', $profile->id)
            ->assertJsonPath('data.business_name', 'Siomay Bandung Asli')
            ->assertJsonPath('data.is_selling', true);

        // GET /merchants/{id}/rating
        $ratingResponse = $this->withToken($token)->getJson("/api/v1/merchants/{$profile->id}/rating");
        $ratingResponse->assertOk()
            ->assertJsonPath('data.merchant_id', $profile->id)
            ->assertJsonStructure(['data' => ['merchant_id', 'average_rating', 'total_reviews']]);
    }
}

