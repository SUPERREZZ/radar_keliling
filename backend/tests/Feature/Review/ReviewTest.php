<?php

namespace Tests\Feature\Review;

use App\Models\Call;
use App\Models\MerchantProfile;
use App\Models\Review;
use App\Models\ReviewReport;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class ReviewTest extends TestCase
{
    use RefreshDatabase;

    private function createMerchant(string $email = 'pedagang@example.com'): array
    {
        $user = User::factory()->create([
            'email' => $email,
            'role' => User::ROLE_MERCHANT,
            'email_verified' => true,
        ]);

        $profile = MerchantProfile::create([
            'user_id' => $user->id,
            'business_name' => 'Bakso Mas Budi',
            'description' => 'Bakso urat khas Malang',
            'is_selling' => true,
        ]);

        return [$user, $profile];
    }

    private function createBuyer(string $email = 'pembeli@example.com'): User
    {
        return User::factory()->create([
            'email' => $email,
            'role' => User::ROLE_BUYER,
            'email_verified' => true,
        ]);
    }

    private function createAdmin(string $email = 'admin@example.com'): User
    {
        return User::factory()->create([
            'email' => $email,
            'role' => User::ROLE_ADMIN,
            'email_verified' => true,
        ]);
    }

    public function test_buyer_can_submit_review_for_accepted_call(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer = $this->createBuyer();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_ACCEPTED,
            'location_consent' => true,
            'created_at' => now(),
        ]);

        $response = $this->actingAs($buyer)->postJson("/api/v1/calls/{$call->id}/review", [
            'rating' => 5,
            'review_text' => 'Baksosnya enak banget dan kuahnya gurih mantap!',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.rating', 5)
            ->assertJsonStructure([
                'data' => ['id', 'rating', 'created_at'],
            ]);

        $this->assertDatabaseHas('reviews', [
            'call_id' => $call->id,
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'rating' => 5,
            'review_text' => 'Baksosnya enak banget dan kuahnya gurih mantap!',
            'moderation_status' => 'visible',
        ]);
    }

    public function test_buyer_can_submit_review_for_completed_call(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer = $this->createBuyer();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_COMPLETED,
            'location_consent' => true,
            'created_at' => now(),
        ]);

        $response = $this->actingAs($buyer)->postJson("/api/v1/calls/{$call->id}/review", [
            'rating' => 4,
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.rating', 4);
    }

    public function test_cannot_review_if_call_status_is_pending(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer = $this->createBuyer();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_PENDING,
            'location_consent' => true,
            'created_at' => now(),
        ]);

        $response = $this->actingAs($buyer)->postJson("/api/v1/calls/{$call->id}/review", [
            'rating' => 5,
        ]);

        $response->assertStatus(400)
            ->assertJsonPath('error.code', 'INVALID_CALL_STATE');
    }

    public function test_cannot_submit_duplicate_review_for_same_call(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer = $this->createBuyer();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_ACCEPTED,
            'location_consent' => true,
            'created_at' => now(),
        ]);

        Review::create([
            'call_id' => $call->id,
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'rating' => 4,
            'moderation_status' => 'visible',
        ]);

        $response = $this->actingAs($buyer)->postJson("/api/v1/calls/{$call->id}/review", [
            'rating' => 5,
        ]);

        $response->assertStatus(409)
            ->assertJsonPath('error.code', 'REVIEW_ALREADY_EXISTS');
    }

    public function test_merchant_cannot_submit_review(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer = $this->createBuyer();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_ACCEPTED,
            'location_consent' => true,
            'created_at' => now(),
        ]);

        $response = $this->actingAs($merchantUser)->postJson("/api/v1/calls/{$call->id}/review", [
            'rating' => 5,
        ]);

        $response->assertStatus(403)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_other_buyer_cannot_review_someone_elses_call(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer1 = $this->createBuyer('buyer1@example.com');
        $buyer2 = $this->createBuyer('buyer2@example.com');

        $call = Call::create([
            'buyer_id' => $buyer1->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_ACCEPTED,
            'location_consent' => true,
            'created_at' => now(),
        ]);

        $response = $this->actingAs($buyer2)->postJson("/api/v1/calls/{$call->id}/review", [
            'rating' => 5,
        ]);

        $response->assertStatus(403)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_rating_validation_requires_1_to_5(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer = $this->createBuyer();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_ACCEPTED,
            'location_consent' => true,
            'created_at' => now(),
        ]);

        $response = $this->actingAs($buyer)->postJson("/api/v1/calls/{$call->id}/review", [
            'rating' => 6,
        ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_ERROR');

        $response2 = $this->actingAs($buyer)->postJson("/api/v1/calls/{$call->id}/review", [
            'rating' => 0,
        ]);

        $response2->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_ERROR');
    }

    public function test_public_merchant_rating_aggregates_properly(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer1 = $this->createBuyer('b1@example.com');
        $buyer2 = $this->createBuyer('b2@example.com');

        $call1 = Call::create([
            'buyer_id' => $buyer1->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_ACCEPTED,
            'created_at' => now(),
        ]);

        $call2 = Call::create([
            'buyer_id' => $buyer2->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_ACCEPTED,
            'created_at' => now(),
        ]);

        Review::create([
            'call_id' => $call1->id,
            'buyer_id' => $buyer1->id,
            'merchant_id' => $profile->id,
            'rating' => 5,
            'review_text' => 'Enak',
            'moderation_status' => 'visible',
        ]);

        Review::create([
            'call_id' => $call2->id,
            'buyer_id' => $buyer2->id,
            'merchant_id' => $profile->id,
            'rating' => 4,
            'review_text' => 'Bagus',
            'moderation_status' => 'visible',
        ]);

        // Akses publik tanpa token
        $response = $this->getJson("/api/v1/merchants/{$profile->id}/rating");

        $response->assertStatus(200)
            ->assertJsonPath('data.merchant_id', $profile->id)
            ->assertJsonPath('data.average_rating', 4.5)
            ->assertJsonPath('data.total_reviews', 2);
    }

    public function test_user_can_report_review(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer = $this->createBuyer('buyer@example.com');
        $reporter = $this->createBuyer('reporter@example.com');

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_ACCEPTED,
            'created_at' => now(),
        ]);

        $review = Review::create([
            'call_id' => $call->id,
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'rating' => 1,
            'review_text' => 'Kata-kata tidak pantas di sini',
            'moderation_status' => 'visible',
        ]);

        $response = $this->actingAs($reporter)->postJson("/api/v1/reviews/{$review->id}/reports", [
            'reason' => 'Ulasan mengandung kata-kata kasar.',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.message', 'Laporan berhasil dikirim.')
            ->assertJsonStructure([
                'data' => ['id', 'message'],
            ]);

        $this->assertDatabaseHas('review_reports', [
            'review_id' => $review->id,
            'reporter_id' => $reporter->id,
            'reason' => 'Ulasan mengandung kata-kata kasar.',
            'status' => 'pending',
        ]);

        // Pelapor yang sama tidak dapat melakukan spam laporan pada ulasan yang sama
        $this->actingAs($reporter)->postJson("/api/v1/reviews/{$review->id}/reports", [
            'reason' => 'Spam laporan kedua.',
        ])->assertStatus(409)
            ->assertJsonPath('error.code', 'REPORT_ALREADY_EXISTS');
    }

    public function test_admin_can_view_reports_and_hide_review(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer = $this->createBuyer('buyer@example.com');
        $reporter = $this->createBuyer('reporter@example.com');
        $admin = $this->createAdmin();

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_ACCEPTED,
            'created_at' => now(),
        ]);

        $review = Review::create([
            'call_id' => $call->id,
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'rating' => 1,
            'review_text' => 'Komentar spam',
            'moderation_status' => 'visible',
        ]);

        $report = ReviewReport::create([
            'review_id' => $review->id,
            'reporter_id' => $reporter->id,
            'reason' => 'Spam berulang',
            'status' => 'pending',
        ]);

        // Non-admin harus ditolak 403
        $this->actingAs($buyer)->getJson('/api/v1/admin/review-reports')
            ->assertStatus(403);

        $this->actingAs($buyer)->patchJson("/api/v1/admin/reviews/{$review->id}/hide")
            ->assertStatus(403);

        // Admin melihat laporan
        $response = $this->actingAs($admin)->getJson('/api/v1/admin/review-reports');
        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    ['id', 'review_id', 'reporter_id', 'reason', 'status', 'created_at'],
                ],
            ]);

        // Admin sembunyikan review
        $hideResponse = $this->actingAs($admin)->patchJson("/api/v1/admin/reviews/{$review->id}/hide");
        $hideResponse->assertStatus(200)
            ->assertJsonPath('data.id', $review->id)
            ->assertJsonPath('data.moderation_status', 'hidden');

        $this->assertDatabaseHas('reviews', [
            'id' => $review->id,
            'moderation_status' => 'hidden',
        ]);

        $this->assertDatabaseHas('review_reports', [
            'id' => $report->id,
            'status' => 'reviewed',
        ]);

        // Rating merchant kini 0 karena review sudah disembunyikan
        $ratingRes = $this->getJson("/api/v1/merchants/{$profile->id}/rating");
        $ratingRes->assertStatus(200)
            ->assertJsonPath('data.total_reviews', 0)
            ->assertJsonPath('data.average_rating', 0);
    }

    public function test_merchant_cannot_report_review(): void
    {
        [$merchantUser, $profile] = $this->createMerchant();
        $buyer = $this->createBuyer('buyer_rep@example.com');

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_ACCEPTED,
            'created_at' => now(),
        ]);

        $review = Review::create([
            'call_id' => $call->id,
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'rating' => 2,
            'review_text' => 'Kurang asin',
            'moderation_status' => 'visible',
        ]);

        $this->actingAs($merchantUser)->postJson("/api/v1/reviews/{$review->id}/reports", [
            'reason' => 'Saya tidak suka ulasan ini',
        ])->assertStatus(403)
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_admin_can_list_filter_and_unhide_reviews(): void
    {
        [, $profile] = $this->createMerchant();
        $buyer = $this->createBuyer('buyer_unhide@example.com');
        $admin = $this->createAdmin('admin_unhide@example.com');

        $call = Call::create([
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'status' => Call::STATUS_COMPLETED,
            'created_at' => now(),
        ]);

        $review = Review::create([
            'call_id' => $call->id,
            'buyer_id' => $buyer->id,
            'merchant_id' => $profile->id,
            'rating' => 5,
            'review_text' => 'Enak banget',
            'moderation_status' => 'hidden',
        ]);

        // Filter status=hidden
        $listRes = $this->actingAs($admin)->getJson('/api/v1/admin/reviews?status=hidden');
        $listRes->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $review->id);

        // Unhide review
        $unhideRes = $this->actingAs($admin)->patchJson("/api/v1/admin/reviews/{$review->id}/unhide");
        $unhideRes->assertOk()
            ->assertJsonPath('data.moderation_status', 'visible');

        $this->assertDatabaseHas('reviews', [
            'id' => $review->id,
            'moderation_status' => 'visible',
        ]);
    }
}
