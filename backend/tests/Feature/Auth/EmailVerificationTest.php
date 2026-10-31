<?php

namespace Tests\Feature\Auth;

use App\Models\EmailVerificationToken;
use App\Models\User;
use App\Notifications\VerifyEmailNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class EmailVerificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_creates_token_and_sends_notification(): void
    {
        Notification::fake();

        $response = $this->postJson('/api/v1/auth/register', [
            'email' => 'calon@example.com',
            'password' => 'StrongPassword123!',
            'role' => 'buyer',
        ]);

        $response->assertCreated();

        $user = User::where('email', 'calon@example.com')->firstOrFail();
        $this->assertFalse($user->email_verified);
        $this->assertDatabaseHas('email_verification_tokens', ['user_id' => $user->id]);

        Notification::assertSentTo($user, VerifyEmailNotification::class);
    }

    public function test_verify_email_success(): void
    {
        $user = User::factory()->unverified()->create();
        $token = EmailVerificationToken::createForUser($user);

        $response = $this->postJson('/api/v1/auth/email/verify', [
            'token' => $token,
        ]);

        $response->assertOk()
            ->assertJsonPath('data.message', 'Email berhasil diverifikasi.');

        $this->assertTrue($user->fresh()->email_verified);
        $this->assertNotNull(EmailVerificationToken::where('user_id', $user->id)->first()->used_at);
    }

    public function test_verify_email_with_invalid_token_fails(): void
    {
        $response = $this->postJson('/api/v1/auth/email/verify', [
            'token' => 'invalid-token',
        ]);

        $response->assertStatus(400)
            ->assertJsonPath('error.code', 'INVALID_VERIFICATION_TOKEN');
    }

    public function test_verify_email_with_expired_token_fails(): void
    {
        $user = User::factory()->unverified()->create();
        $token = 'expired123';
        EmailVerificationToken::create([
            'user_id' => $user->id,
            'token_hash' => hash('sha256', $token),
            'expires_at' => now()->subMinutes(10),
            'created_at' => now()->subMinutes(70),
        ]);

        $response = $this->postJson('/api/v1/auth/email/verify', [
            'token' => $token,
        ]);

        $response->assertStatus(400)
            ->assertJsonPath('error.code', 'INVALID_VERIFICATION_TOKEN');
    }

    public function test_resend_verification_success(): void
    {
        Notification::fake();

        $user = User::factory()->unverified()->create();

        $response = $this->postJson('/api/v1/auth/email/resend', [
            'email' => $user->email,
        ]);

        $response->assertOk()
            ->assertJsonPath('data.message', 'Email verifikasi telah dikirim ulang.');

        Notification::assertSentTo($user, VerifyEmailNotification::class);
    }

    public function test_resend_verification_already_verified_fails(): void
    {
        $user = User::factory()->create(['email_verified' => true]);

        $response = $this->postJson('/api/v1/auth/email/resend', [
            'email' => $user->email,
        ]);

        $response->assertStatus(400)
            ->assertJsonPath('error.code', 'EMAIL_ALREADY_VERIFIED');
    }
}

