<?php

namespace Tests\Feature\Merchant;

use App\Models\Menu;
use App\Models\MerchantProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class MenuTest extends TestCase
{
    use RefreshDatabase;

    private function createMerchantWithProfile(): array
    {
        $user = User::factory()->merchant()->create();
        $token = $user->createToken('mobile')->plainTextToken;
        $profile = MerchantProfile::create([
            'user_id' => $user->id,
            'business_name' => 'Bakso Pak Budi',
            'is_selling' => true,
        ]);

        return [$user, $token, $profile];
    }

    public function test_merchant_can_create_menu(): void
    {
        [, $token, $profile] = $this->createMerchantWithProfile();

        $response = $this->withToken($token)->postJson('/api/v1/merchant/menus', [
            'name' => 'Bakso Biasa',
            'description' => 'Kuah bening dengan bakso sapi.',
            'price' => 15000,
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.name', 'Bakso Biasa')
            ->assertJsonPath('data.price', 15000)
            ->assertJsonPath('data.is_available', true)
            ->assertJsonPath('data.photos', []);

        $this->assertDatabaseHas('menus', [
            'merchant_id' => $profile->id,
            'name' => 'Bakso Biasa',
            'price' => 15000,
        ]);
    }

    public function test_merchant_can_list_and_update_menu(): void
    {
        [, $token, $profile] = $this->createMerchantWithProfile();

        $menu = Menu::create([
            'merchant_id' => $profile->id,
            'name' => 'Bakso Biasa',
            'price' => 15000,
            'is_available' => true,
        ]);

        // List
        $listResponse = $this->withToken($token)->getJson('/api/v1/merchant/menus');
        $listResponse->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $menu->id);

        // Update
        $updateResponse = $this->withToken($token)->putJson("/api/v1/merchant/menus/{$menu->id}", [
            'name' => 'Bakso Spesial Telur',
            'price' => 18000,
            'is_available' => false,
        ]);

        $updateResponse->assertOk()
            ->assertJsonPath('data.name', 'Bakso Spesial Telur')
            ->assertJsonPath('data.price', 18000)
            ->assertJsonPath('data.is_available', false);
    }

    public function test_merchant_can_delete_menu(): void
    {
        [, $token, $profile] = $this->createMerchantWithProfile();

        $menu = Menu::create([
            'merchant_id' => $profile->id,
            'name' => 'Bakso Rusuk',
            'price' => 25000,
        ]);

        $this->withToken($token)->deleteJson("/api/v1/merchant/menus/{$menu->id}")
            ->assertNoContent();

        $this->assertDatabaseMissing('menus', ['id' => $menu->id]);
    }

    public function test_merchant_can_upload_and_delete_menu_photo(): void
    {
        Storage::fake('public');
        [, $token, $profile] = $this->createMerchantWithProfile();

        $menu = Menu::create([
            'merchant_id' => $profile->id,
            'name' => 'Sate Ayam',
            'price' => 20000,
        ]);

        $file = UploadedFile::fake()->image('sate.jpg', 400, 400);

        $uploadResponse = $this->withToken($token)->postJson("/api/v1/merchant/menus/{$menu->id}/photos", [
            'photo' => $file,
        ]);

        $uploadResponse->assertStatus(201)
            ->assertJsonStructure(['data' => ['id', 'url']]);

        $photoId = $uploadResponse->json('data.id');
        $this->assertDatabaseHas('menu_photos', ['id' => $photoId, 'menu_id' => $menu->id]);

        // Delete photo
        $this->withToken($token)->deleteJson("/api/v1/merchant/menu-photos/{$photoId}")
            ->assertNoContent();

        $this->assertDatabaseMissing('menu_photos', ['id' => $photoId]);
    }

    public function test_cannot_upload_more_than_five_photos_per_menu(): void
    {
        Storage::fake('public');
        [, $token, $profile] = $this->createMerchantWithProfile();

        $menu = Menu::create([
            'merchant_id' => $profile->id,
            'name' => 'Sate Kambing',
            'price' => 30000,
        ]);

        // Buat 5 foto
        for ($i = 1; $i <= 5; $i++) {
            $menu->photos()->create(['storage_path' => "menus/photo_{$i}.jpg"]);
        }

        $file = UploadedFile::fake()->image('photo_6.jpg');

        $response = $this->withToken($token)->postJson("/api/v1/merchant/menus/{$menu->id}/photos", [
            'photo' => $file,
        ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'MAX_PHOTOS_EXCEEDED');
    }

    public function test_public_can_view_merchant_menus(): void
    {
        [, , $profile] = $this->createMerchantWithProfile();

        Menu::create([
            'merchant_id' => $profile->id,
            'name' => 'Menu Tersedia',
            'price' => 10000,
            'is_available' => true,
        ]);

        Menu::create([
            'merchant_id' => $profile->id,
            'name' => 'Menu Habis',
            'price' => 12000,
            'is_available' => false,
        ]);

        $user = User::factory()->create();
        $token = $user->createToken('mobile')->plainTextToken;

        $response = $this->withToken($token)->getJson("/api/v1/merchants/{$profile->id}/menus");

        $response->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Menu Tersedia');
    }

    public function test_swagger_documentation_endpoint_is_accessible(): void
    {
        $response = $this->get('/docs/api');
        $response->assertOk();
    }

    public function test_merchant_cannot_modify_or_delete_other_merchants_menu(): void
    {
        [, , $profile1] = $this->createMerchantWithProfile();
        [, $token2] = $this->createMerchantWithProfile();

        $menu = Menu::create([
            'merchant_id' => $profile1->id,
            'name' => 'Menu Merchant 1',
            'price' => 10000,
        ]);

        // Merchant 2 mencoba update menu Merchant 1
        $this->withToken($token2)->putJson("/api/v1/merchant/menus/{$menu->id}", [
            'name' => 'Dibajak',
            'price' => 99999,
        ])->assertStatus(404);

        // Merchant 2 mencoba hapus menu Merchant 1
        $this->withToken($token2)->deleteJson("/api/v1/merchant/menus/{$menu->id}")
            ->assertStatus(404);

        $this->assertDatabaseHas('menus', ['id' => $menu->id, 'name' => 'Menu Merchant 1']);
    }

    public function test_merchant_cannot_delete_other_merchants_menu_photo(): void
    {
        [, , $profile1] = $this->createMerchantWithProfile();
        [, $token2] = $this->createMerchantWithProfile();

        $menu = Menu::create([
            'merchant_id' => $profile1->id,
            'name' => 'Menu Foto',
            'price' => 10000,
        ]);

        $photo = $menu->photos()->create(['storage_path' => 'menus/test.jpg']);

        $this->withToken($token2)->deleteJson("/api/v1/merchant/menu-photos/{$photo->id}")
            ->assertStatus(404);

        $this->assertDatabaseHas('menu_photos', ['id' => $photo->id]);
    }

    public function test_menu_photo_upload_validates_image_file(): void
    {
        Storage::fake('public');
        [, $token, $profile] = $this->createMerchantWithProfile();

        $menu = Menu::create([
            'merchant_id' => $profile->id,
            'name' => 'Menu Uji',
            'price' => 10000,
        ]);

        // File teks biasa bukan gambar
        $fakeFile = UploadedFile::fake()->create('document.txt', 50, 'text/plain');

        $response = $this->withToken($token)->postJson("/api/v1/merchant/menus/{$menu->id}/photos", [
            'photo' => $fakeFile,
        ]);

        $response->assertStatus(422)
            ->assertJsonPath('error.code', 'VALIDATION_ERROR');
    }

    public function test_merchant_can_sort_and_filter_menus(): void
    {
        [, $token, $profile] = $this->createMerchantWithProfile();

        Menu::create([
            'merchant_id' => $profile->id,
            'name' => 'Es Teh Manis',
            'description' => 'Segar dingin',
            'price' => 5000,
            'is_available' => true,
        ]);

        Menu::create([
            'merchant_id' => $profile->id,
            'name' => 'Bakso Urat Spesial',
            'description' => 'Daging sapi asli',
            'price' => 20000,
            'is_available' => true,
        ]);

        Menu::create([
            'merchant_id' => $profile->id,
            'name' => 'Sate Kambing Muda',
            'description' => 'Bumbu kecap pedas',
            'price' => 35000,
            'is_available' => false,
        ]);

        // 1. Sort price_asc
        $priceAsc = $this->withToken($token)->getJson('/api/v1/merchant/menus?sort=price_asc');
        $priceAsc->assertOk()
            ->assertJsonPath('data.0.name', 'Es Teh Manis')
            ->assertJsonPath('data.1.name', 'Bakso Urat Spesial')
            ->assertJsonPath('data.2.name', 'Sate Kambing Muda');

        // 2. Sort price_desc
        $priceDesc = $this->withToken($token)->getJson('/api/v1/merchant/menus?sort=price_desc');
        $priceDesc->assertOk()
            ->assertJsonPath('data.0.name', 'Sate Kambing Muda')
            ->assertJsonPath('data.2.name', 'Es Teh Manis');

        // 3. Sort name_asc
        $nameAsc = $this->withToken($token)->getJson('/api/v1/merchant/menus?sort=name_asc');
        $nameAsc->assertOk()
            ->assertJsonPath('data.0.name', 'Bakso Urat Spesial')
            ->assertJsonPath('data.1.name', 'Es Teh Manis')
            ->assertJsonPath('data.2.name', 'Sate Kambing Muda');

        // 4. Filter is_available=true
        $availRes = $this->withToken($token)->getJson('/api/v1/merchant/menus?is_available=true');
        $availRes->assertOk()->assertJsonCount(2, 'data');

        // 5. Search by keyword
        $searchRes = $this->withToken($token)->getJson('/api/v1/merchant/menus?search=bakso');
        $searchRes->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Bakso Urat Spesial');
    }

    public function test_merchant_can_toggle_menu_availability(): void
    {
        [, $token, $profile] = $this->createMerchantWithProfile();

        $menu = Menu::create([
            'merchant_id' => $profile->id,
            'name' => 'Mie Ayam Jamur',
            'price' => 14000,
            'is_available' => true,
        ]);

        $res1 = $this->withToken($token)->patchJson("/api/v1/merchant/menus/{$menu->id}/availability");
        $res1->assertOk()->assertJsonPath('data.is_available', false);

        $res2 = $this->withToken($token)->patchJson("/api/v1/merchant/menus/{$menu->id}/availability");
        $res2->assertOk()->assertJsonPath('data.is_available', true);
    }
}

