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

        // Jam-jam puncak aktivitas pembeli
        $peakHours = [
            8, 9,        // Sarapan pagi
            11, 12, 13,  // Jam makan siang kantor & kampus
            15, 16, 17,  // Jam jajan sore
            19, 20, 21,  // Jam makan malam
        ];

        // Jam saat ini untuk memastikan heatmap langsung menyala saat demo
        $currentHour = (int) now()->format('G');
        if (! in_array($currentHour, $peakHours, true)) {
            $peakHours[] = $currentHour;
        }

        $now = now();
        $batch = [];

        foreach ($clusters as $cluster) {
            foreach ($peakHours as $hour) {
                // Tiap klaster memiliki 20 - 45 titik pencarian per jam puncak
                $pointsCount = rand(25, 45);

                for ($i = 0; $i < $pointsCount; $i++) {
                    // Beri offset acak sekitar 50 - 300 meter dari pusat klaster
                    $latOffset = (rand(-250, 250) / 100000.0);
                    $lngOffset = (rand(-250, 250) / 100000.0);

                    $pointLat = $cluster['lat'] + $latOffset;
                    $pointLng = $cluster['lng'] + $lngOffset;

                    $category = $cluster['categories'][array_rand($cluster['categories'])];

                    // Set waktu tepat di jam tersebut
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

