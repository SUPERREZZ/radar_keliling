<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_buyer_success(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'email' => 'Budi@Example.com',
            'password' => 'StrongPassword123!',
            'role' => 'buyer',
        ])->assertCreated()
            ->assertJsonPath('data.message', 'Registrasi berhasil. Silakan verifikasi email Anda.');

        $this->assertDatabaseHas('users', ['email' => 'budi@example.com', 'role' => 'buyer', 'email_verified' => false]);
    }

    public function test_register_rejects_admin_role(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'email' => 'admin@example.com',
            'password' => 'StrongPassword123!',
            'role' => 'admin',
        ])->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_ERROR')
            ->assertJsonStructure(['error' => ['code', 'message', 'details' => ['role']]]);
    }

    public function test_login_success_returns_token_and_user(): void
    {
        User::factory()->create(['email' => 'buyer@example.com']);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'buyer@example.com',
            'password' => 'password',
        ])->assertOk()
            ->assertJsonPath('data.token_type', 'Bearer')
            ->assertJsonPath('data.user.role', 'buyer')
            ->assertJsonPath('data.user.email_verified', true)
            ->assertJsonStructure(['data' => ['token', 'token_type', 'user' => ['id', 'email', 'role', 'email_verified']]]);
    }

    public function test_login_wrong_password(): void
    {
        User::factory()->create(['email' => 'buyer@example.com']);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'buyer@example.com',
            'password' => 'salah',
        ])->assertStatus(401)->assertJsonPath('error.code', 'INVALID_CREDENTIALS');
    }

    public function test_login_unverified_email_is_blocked(): void
    {
        User::factory()->unverified()->create(['email' => 'new@example.com']);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'new@example.com',
            'password' => 'password',
        ])->assertStatus(403)->assertJsonPath('error.code', 'EMAIL_NOT_VERIFIED');
    }

    public function test_me_and_logout(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('mobile')->plainTextToken;

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.id', $user->id);

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertNoContent();

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_me_without_token_returns_standard_error(): void
    {
        $this->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }
}
