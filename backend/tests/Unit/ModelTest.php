<?php

namespace Tests\Unit;

use App\Models\Call;
use App\Models\MerchantProfile;
use App\Models\Review;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ModelTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_role_methods(): void
    {
        $buyer = new User(['role' => User::ROLE_BUYER]);
        $this->assertTrue($buyer->isBuyer());
        $this->assertFalse($buyer->isMerchant());
        $this->assertFalse($buyer->isAdmin());

        $merchant = new User(['role' => User::ROLE_MERCHANT]);
        $this->assertFalse($merchant->isBuyer());
        $this->assertTrue($merchant->isMerchant());
        $this->assertFalse($merchant->isAdmin());

        $admin = new User(['role' => User::ROLE_ADMIN]);
        $this->assertFalse($admin->isBuyer());
        $this->assertFalse($admin->isMerchant());
        $this->assertTrue($admin->isAdmin());
    }

    public function test_merchant_profile_rating_attributes(): void
    {
        $user = User::factory()->merchant()->create();
        $buyer = User::factory()->create(['role' => User::ROLE_BUYER]);

        $profile = MerchantProfile::create([
            'user_id' => $user->id,
            'business_name' => 'Kwetiau Sapi Cak Nur',
            'is_selling' => true,
        ]);

        // Belum ada review -> rating 0.0, total 0
        $this->assertSame(0.0, $profile->average_rating);
        $this->assertSame(0, $profile->total_reviews);

        $call1 = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_ACCEPTED,
            'created_at' => now(),
        ]);

        Review::create([
            'call_id' => $call1->id,
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'rating' => 4,
            'moderation_status' => Review::STATUS_VISIBLE,
        ]);

        $this->assertSame(4.0, $profile->fresh()->average_rating);
        $this->assertSame(1, $profile->fresh()->total_reviews);

        // Tambah review kedua
        $buyer2 = User::factory()->create(['role' => User::ROLE_BUYER]);
        $call2 = Call::create([
            'buyer_id' => $buyer2->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_COMPLETED,
            'created_at' => now(),
        ]);

        Review::create([
            'call_id' => $call2->id,
            'buyer_id' => $buyer2->id,
            'merchant_id' => $profile->id,
            'rating' => 5,
            'moderation_status' => Review::STATUS_VISIBLE,
        ]);

        // Rata-rata (4 + 5) / 2 = 4.5
        $this->assertSame(4.5, $profile->fresh()->average_rating);
        $this->assertSame(2, $profile->fresh()->total_reviews);
    }

    public function test_call_has_review_attribute(): void
    {
        $merchantUser = User::factory()->merchant()->create();
        $profile = MerchantProfile::create([
            'user_id' => $merchantUser->id,
            'business_name' => 'Nasi Goreng Pak Kumis',
            'is_selling' => true,
        ]);
        $buyer = User::factory()->create(['role' => User::ROLE_BUYER]);

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_COMPLETED,
            'created_at' => now(),
        ]);

        // Belum ada review
        $this->assertFalse($call->has_review);

        // Buat review
        Review::create([
            'call_id' => $call->id,
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'rating' => 5,
            'moderation_status' => Review::STATUS_VISIBLE,
        ]);

        $this->assertTrue($call->fresh()->has_review);
    }
}

