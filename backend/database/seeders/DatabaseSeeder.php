<?php

namespace Database\Seeders;

use App\Models\Call;
use App\Models\Menu;
use App\Models\MerchantLocation;
use App\Models\MerchantProfile;
use App\Models\Review;
use App\Models\User;
use App\Services\Geohash;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $defaultPassword = Hash::make('password');

        // 1. Akun Admin
        $admin = User::firstOrCreate(
            ['email' => 'admin@radarkeliling.com'],
            [
                'password' => $defaultPassword,
                'role' => User::ROLE_ADMIN,
                'email_verified' => true,
            ]
        );

        // 2. Akun Pembeli Utama (Buyer)
        $buyer = User::firstOrCreate(
            ['email' => 'buyer@radarkeliling.com'],
            [
                'password' => $defaultPassword,
                'role' => User::ROLE_BUYER,
                'email_verified' => true,
            ]
        );

        $buyer2 = User::firstOrCreate(
            ['email' => 'andi@radarkeliling.com'],
            [
                'password' => $defaultPassword,
                'role' => User::ROLE_BUYER,
                'email_verified' => true,
            ]
        );

        // 3. Daftar Pedagang Keliling (Merchants)
        $merchantsData = [
            [
                'email' => 'budi@radarkeliling.com',
                'business_name' => 'Bakso Malang Cak Budi',
                'description' => 'Bakso urat daging sapi asli Malang, pentol kasar, tahu bakso gurih.',
                'is_selling' => true,
                'lat' => -7.2625,
                'lng' => 112.7485,
                'accuracy' => 8.5,
                'menus' => [
                    ['name' => 'Bakso Halus Spesial', 'price' => 15000, 'description' => 'Pentol halus lembut dengan kuah kaldu sapi pekat.'],
                    ['name' => 'Bakso Urat Granat', 'price' => 18000, 'description' => 'Bakso urat kasar daging sapi asli dengan sensasi kenyal gurih.'],
                    ['name' => 'Bakso Telur Puyuh', 'price' => 20000, 'description' => 'Bakso isi telur puyuh komplit dengan tahu bakso dan siomay basah.'],
                    ['name' => 'Es Teh Manis Jumbo', 'price' => 5000, 'description' => 'Es teh wangi melati segar gelas jumbo.'],
                ],
            ],
            [
                'email' => 'siti@radarkeliling.com',
                'business_name' => 'Siomay & Batagor Bu Siti',
                'description' => 'Siomay ikan tenggiri asli dengan bumbu kacang kental gurih khas Bandung.',
                'is_selling' => true,
                'lat' => -7.2640,
                'lng' => 112.7510,
                'accuracy' => 10.0,
                'menus' => [
                    ['name' => 'Paket Siomay Komplit', 'price' => 15000, 'description' => 'Siomay tenggiri, tahu, telur, kubis, kentang, dan bumbu kacang kental.'],
                    ['name' => 'Batagor Renyah Gurih', 'price' => 16000, 'description' => 'Bakso tahu goreng renyah disiram saus kacang pedas manis.'],
                    ['name' => 'Es Jeruk Peras Murni', 'price' => 6000, 'description' => 'Jeruk peras manis segar tanpa pemanis buatan.'],
                ],
            ],
            [
                'email' => 'joko@radarkeliling.com',
                'business_name' => 'Es Cendol Dawet Mas Joko',
                'description' => 'Cendol tepung beras alami gula aren murni santan kelapa kental segar.',
                'is_selling' => true,
                'lat' => -7.2605,
                'lng' => 112.7470,
                'accuracy' => 6.0,
                'menus' => [
                    ['name' => 'Es Cendol Dawet Nangka', 'price' => 10000, 'description' => 'Cendol dawet gula aren dengan potongan buah nangka harum manis.'],
                    ['name' => 'Es Dawet Durian Spesial', 'price' => 15000, 'description' => 'Dawet santan segar dengan topping daging durian asli melimpah.'],
                    ['name' => 'Es Cincau Hitam Segar', 'price' => 8000, 'description' => 'Cincau hitam kenyal dingin menyegarkan.'],
                ],
            ],
            [
                'email' => 'eneng@radarkeliling.com',
                'business_name' => 'Cilok & Cireng Crispy Teh Eneng',
                'description' => 'Cilok kenyal bumbu kacang pedas manis dan cireng renyah bumbu rujak.',
                'is_selling' => true,
                'lat' => -7.2670,
                'lng' => 112.7535,
                'accuracy' => 7.5,
                'menus' => [
                    ['name' => 'Cilok Daging Bumbu Kacang', 'price' => 10000, 'description' => '10 butir cilok isi daging sapi cincang bumbu kacang medok.'],
                    ['name' => 'Cireng Crispy Bumbu Rujak', 'price' => 12000, 'description' => 'Cireng garing di luar kenyal di dalam dengan sambal rujak gula merah.'],
                ],
            ],
            [
                'email' => 'ali@radarkeliling.com',
                'business_name' => 'Martabak & Terang Bulan Bang Ali',
                'description' => 'Martabak telur bebek istimewa dan terang bulan aneka topping manis.',
                'is_selling' => false,
                'lat' => -7.2700,
                'lng' => 112.7560,
                'accuracy' => 12.0,
                'menus' => [
                    ['name' => 'Martabak Telur Bebek Spesial', 'price' => 35000, 'description' => 'Martabak telur 3 butir dengan daging cincang daun bawang gurih renyah.'],
                    ['name' => 'Terang Bulan Coklat Keju Wijen', 'price' => 28000, 'description' => 'Kue terang bulan tebal empuk bertabur coklat meses dan keju kraft.'],
                ],
            ],
        ];

        $merchantProfiles = [];

        foreach ($merchantsData as $data) {
            $user = User::firstOrCreate(
                ['email' => $data['email']],
                [
                    'password' => $defaultPassword,
                    'role' => User::ROLE_MERCHANT,
                    'email_verified' => true,
                ]
            );

            $profile = MerchantProfile::updateOrCreate(
                ['user_id' => $user->id],
                [
                    'business_name' => $data['business_name'],
                    'description' => $data['description'],
                    'is_selling' => $data['is_selling'],
                ]
            );

            $merchantProfiles[] = $profile;

            // Simpan koordinat lokasi merchant PostGIS
            $nowIso = now()->toIso8601String();
            MerchantLocation::updateCoordinates(
                $profile->id,
                $data['lat'],
                $data['lng'],
                $data['accuracy'],
                $nowIso
            );

            // Menu makanan & minuman
            foreach ($data['menus'] as $m) {
                Menu::firstOrCreate(
                    [
                        'merchant_id' => $profile->id,
                        'name' => $m['name'],
                    ],
                    [
                        'price' => $m['price'],
                        'description' => $m['description'],
                        'is_available' => true,
                    ]
                );
            }
        }

        // 4. Sample Calls & Reviews
        if (isset($merchantProfiles[0])) {
            $call1 = Call::firstOrCreate(
                [
                    'buyer_id' => $buyer->id,
                    'merchant_id' => $merchantProfiles[0]->id,
                ],
                [
                    'status' => Call::STATUS_COMPLETED,
                    'location_consent' => true,
                    'consented_at' => now()->subHours(2),
                    'created_at' => now()->subHours(2),
                ]
            );

            Review::firstOrCreate(
                ['call_id' => $call1->id],
                [
                    'buyer_id' => $buyer->id,
                    'merchant_id' => $merchantProfiles[0]->id,
                    'rating' => 5,
                    'review_text' => 'Pelayanan ramah sekali, baksosnya kenyal mantap dan kuahnya gurih beneran!',
                    'moderation_status' => Review::STATUS_VISIBLE,
                ]
            );
        }

        if (isset($merchantProfiles[1])) {
            $call2 = Call::firstOrCreate(
                [
                    'buyer_id' => $buyer2->id,
                    'merchant_id' => $merchantProfiles[1]->id,
                ],
                [
                    'status' => Call::STATUS_COMPLETED,
                    'location_consent' => true,
                    'consented_at' => now()->subHours(1),
                    'created_at' => now()->subHours(1),
                ]
            );

            Review::firstOrCreate(
                ['call_id' => $call2->id],
                [
                    'buyer_id' => $buyer2->id,
                    'merchant_id' => $merchantProfiles[1]->id,
                    'rating' => 5,
                    'review_text' => 'Siomay ikannya berasa banget, bumbu kacangnya kental pas pedas manisnya!',
                    'moderation_status' => Review::STATUS_VISIBLE,
                ]
            );
        }

        // 5. Jalankan DemandLogSeeder untuk data Heatmap
        $this->call(DemandLogSeeder::class);
    }
}
