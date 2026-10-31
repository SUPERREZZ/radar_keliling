<?php

namespace Tests\Feature\Notification;

use App\Models\FcmToken;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class FcmTokenTest extends TestCase
{
    use RefreshDatabase;

    public function test_store_fcm_token_success(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('mobile')->plainTextToken;

        $response = $this->withToken($token)->postJson('/api/v1/auth/fcm-token', [
            'fcm_token' => 'sample-firebase-device-token-12345',
            'device_type' => 'android',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.message', 'FCM token berhasil didaftarkan.');

        $this->assertDatabaseHas('fcm_tokens', [
            'user_id' => $user->id,
            'token' => 'sample-firebase-device-token-12345',
            'device_type' => 'android',
        ]);
    }

    public function test_store_fcm_token_via_alias_with_token_key(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('mobile')->plainTextToken;

        $response = $this->withToken($token)->postJson('/api/v1/fcm/token', [
            'token' => 'alias-token-test',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.message', 'FCM token berhasil didaftarkan.');

        $this->assertDatabaseHas('fcm_tokens', [
            'user_id' => $user->id,
            'token' => 'alias-token-test',
        ]);
    }

    public function test_store_fcm_token_without_token_returns_validation_error(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('mobile')->plainTextToken;

        $response = $this->withToken($token)->postJson('/api/v1/auth/fcm-token', []);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_ERROR');
    }

    public function test_store_fcm_token_reassigns_existing_device_token(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();

        // User A was using this phone
        FcmToken::create([
            'user_id' => $userA->id,
            'token' => 'shared-device-token',
            'device_type' => 'android',
        ]);

        // User B logs in on the same phone
        $tokenB = $userB->createToken('mobile')->plainTextToken;
        $response = $this->withToken($tokenB)->postJson('/api/v1/auth/fcm-token', [
            'fcm_token' => 'shared-device-token',
        ]);

        $response->assertOk();

        // Must now be assigned to user B, not user A
        $this->assertDatabaseHas('fcm_tokens', [
            'user_id' => $userB->id,
            'token' => 'shared-device-token',
        ]);
        $this->assertDatabaseMissing('fcm_tokens', [
            'user_id' => $userA->id,
            'token' => 'shared-device-token',
        ]);
    }

    public function test_delete_specific_fcm_token_success(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('mobile')->plainTextToken;

        FcmToken::create([
            'user_id' => $user->id,
            'token' => 'token-to-delete',
        ]);

        $response = $this->withToken($token)->deleteJson('/api/v1/auth/fcm-token', [
            'fcm_token' => 'token-to-delete',
        ]);

        $response->assertOk()
            ->assertJsonPath('data.message', 'FCM token berhasil dihapus.');

        $this->assertDatabaseMissing('fcm_tokens', [
            'token' => 'token-to-delete',
        ]);
    }

    public function test_delete_fcm_tokens_on_logout_without_body(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('mobile')->plainTextToken;

        FcmToken::create(['user_id' => $user->id, 'token' => 'token-1']);
        FcmToken::create(['user_id' => $user->id, 'token' => 'token-2']);

        $response = $this->withToken($token)->deleteJson('/api/v1/auth/fcm-token');

        $response->assertOk()
            ->assertJsonPath('data.message', 'FCM token berhasil dihapus.');

        $this->assertDatabaseEmpty('fcm_tokens');
    }

    public function test_fcm_endpoints_require_authentication(): void
    {
        $this->postJson('/api/v1/auth/fcm-token', ['fcm_token' => 'test'])
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');

        $this->deleteJson('/api/v1/auth/fcm-token')
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_fcm_service_sends_push_and_prunes_unregistered_tokens(): void
    {
        config([
            'services.fcm.enabled' => true,
            'services.fcm.project_id' => 'radar-keliling-test',
            'services.fcm.access_token' => 'fake-oauth-access-token',
        ]);

        $user = User::factory()->create();
        FcmToken::create(['user_id' => $user->id, 'token' => 'valid-device-token']);
        FcmToken::create(['user_id' => $user->id, 'token' => 'stale-unregistered-token']);

        Http::fake([
            'https://fcm.googleapis.com/v1/projects/radar-keliling-test/messages:send' => function ($request) {
                $token = $request->data()['message']['token'] ?? '';
                if ($token === 'stale-unregistered-token') {
                    return Http::response([
                        'error' => [
                            'code' => 404,
                            'status' => 'NOT_FOUND',
                            'details' => [['errorCode' => 'UNREGISTERED']],
                        ],
                    ], 404);
                }

                return Http::response(['name' => 'projects/radar-keliling-test/messages/1'], 200);
            },
        ]);

        $service = app(FcmService::class);
        $sent = $service->sendToUser($user->id, 'Test Title', 'Test Body', ['call_id' => '123']);

        $this->assertEquals(1, $sent);
        $this->assertDatabaseHas('fcm_tokens', ['token' => 'valid-device-token']);
        $this->assertDatabaseMissing('fcm_tokens', ['token' => 'stale-unregistered-token']);
    }
}

