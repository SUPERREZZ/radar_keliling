<?php

namespace Tests\Unit;

use App\Services\Geohash;
use PHPUnit\Framework\TestCase;

class GeohashTest extends TestCase
{
    public function test_geohash_encodes_with_correct_lengths(): void
    {
        $lat = -7.2575;
        $lng = 112.7521;

        $hash4 = Geohash::encode($lat, $lng, 4);
        $this->assertSame(4, strlen($hash4));

        $hash5 = Geohash::encode($lat, $lng, 5);
        $this->assertSame(5, strlen($hash5));

        $hash6 = Geohash::encode($lat, $lng, 6);
        $this->assertSame(6, strlen($hash6));

        // Presisi yang lebih tinggi harus memiliki prefix yang sama dengan presisi yang lebih rendah
        $this->assertStringStartsWith($hash4, $hash5);
        $this->assertStringStartsWith($hash5, $hash6);
    }

    public function test_nearby_points_share_geohash_prefix(): void
    {
        // Titik 1: Taman Apsari (-7.2625, 112.7485)
        $hash1 = Geohash::encode(-7.2625, 112.7485, 4);

        // Titik 2: Bergeser ~100m (-7.2630, 112.7490)
        $hash2 = Geohash::encode(-7.2630, 112.7490, 4);

        // Dalam grid 4 karakter (~20-40km), titik yang sangat dekat harus berada di geohash yang sama
        $this->assertSame($hash1, $hash2);
    }

    public function test_boundary_coordinates_are_handled(): void
    {
        // Equator & Prime Meridian (Null Island)
        $nullIsland = Geohash::encode(0.0, 0.0, 4);
        $this->assertSame(4, strlen($nullIsland));
        $this->assertSame('s000', $nullIsland);

        // Kutub Utara
        $northPole = Geohash::encode(89.9, 0.0, 4);
        $this->assertSame(4, strlen($northPole));

        // Kutub Selatan
        $southPole = Geohash::encode(-89.9, 0.0, 4);
        $this->assertSame(4, strlen($southPole));
    }
}

