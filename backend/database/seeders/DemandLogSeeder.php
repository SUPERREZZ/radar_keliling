<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DemandLogSeeder extends Seeder
{
    public function run(): void
    {
        // 4 Pusat klaster aktivitas permintaan di area demo
        $clusters = [
            ['lat' => -7.2625, 'lng' => 112.7485, 'name' => 'Taman Apsari / Pusat Kota', 'categories' => ['bakso', 'makanan', 'minuman']],
            ['lat' => -7.2660, 'lng' => 112.7520, 'name' => 'Perkantoran Pemkot', 'categories' => ['siomay', 'makanan', 'gorengan']],
            ['lat' => -7.2750, 'lng' => 112.7600, 'name' => 'Kawasan Kampus & Sekolah', 'categories' => ['cilok', 'minuman', 'bakso', 'gorengan']],
            ['lat' => -7.2850, 'lng' => 112.7350, 'name' => 'Kawasan Hunian & Kuliner Malam', 'categories' => ['martabak', 'makanan', 'bakso']],
        ];

        $now = now();
        $batch = [];

        // Seed seluruh 24 jam (0-23) dengan distribusi realistis agar heatmap selalu hidup kapanpun demo dijalankan
        for ($hour = 0; $hour < 24; $hour++) {
            // Intensitas permintaan dinamis sesuai ritme aktivitas harian
            $pointsCount = match (true) {
                // Jam makan siang & sore-malam (puncak tertinggi)
                in_array($hour, [11, 12, 13, 17, 18, 19, 20], true) => rand(30, 45),
                // Jam sarapan & sore
                in_array($hour, [7, 8, 9, 10, 14, 15, 16, 21], true) => rand(15, 25),
                // Jam kuliner larut malam
                in_array($hour, [22, 23], true) => rand(8, 15),
                // Jam dini hari / subuh
                default => rand(2, 6),
            };

            foreach ($clusters as $cluster) {
                for ($i = 0; $i < $pointsCount; $i++) {
                    // Beri offset acak sekitar 50 - 300 meter dari pusat klaster
                    $latOffset = (rand(-250, 250) / 100000.0);
                    $lngOffset = (rand(-250, 250) / 100000.0);

                    $pointLat = $cluster['lat'] + $latOffset;
                    $pointLng = $cluster['lng'] + $lngOffset;

                    $category = $cluster['categories'][array_rand($cluster['categories'])];

                    // Set waktu tepat di jam tersebut pada hari ini
                    $time = $now->copy()->setHour($hour)->setMinute(rand(0, 59))->setSecond(rand(0, 59));

                    $batch[] = sprintf(
                        "('%s', ST_SetSRID(ST_MakePoint(%f, %f), 4326), '%s')",
                        $category,
                        $pointLng,
                        $pointLat,
                        $time->toDateTimeString()
                    );

                    // Insert dalam batch per 500 rows untuk efisiensi PostgreSQL
                    if (count($batch) >= 500) {
                        DB::statement('INSERT INTO demand_logs (kategori_pencarian, geom, created_at) VALUES '.implode(',', $batch));
                        $batch = [];
                    }
                }
            }
        }

        if (! empty($batch)) {
            DB::statement('INSERT INTO demand_logs (kategori_pencarian, geom, created_at) VALUES '.implode(',', $batch));
        }
    }
}

