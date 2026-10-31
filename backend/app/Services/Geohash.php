<?php

namespace App\Services;

class Geohash
{
    private const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

    /**
     * Encode koordinat latitude dan longitude ke string geohash.
     */
    public static function encode(float $latitude, float $longitude, int $precision = 4): string
    {
        $latInterval = [-90.0, 90.0];
        $lngInterval = [-180.0, 180.0];

        $geohash = '';
        $isEven = true;
        $bit = 0;
        $ch = 0;

        while (strlen($geohash) < $precision) {
            if ($isEven) {
                $mid = ($lngInterval[0] + $lngInterval[1]) / 2;
                if ($longitude >= $mid) {
                    $ch |= (1 << (4 - $bit));
                    $lngInterval[0] = $mid;
                } else {
                    $lngInterval[1] = $mid;
                }
            } else {
                $mid = ($latInterval[0] + $latInterval[1]) / 2;
                if ($latitude >= $mid) {
                    $ch |= (1 << (4 - $bit));
                    $latInterval[0] = $mid;
                } else {
                    $latInterval[1] = $mid;
                }
            }

            $isEven = ! $isEven;

            if ($bit < 4) {
                $bit++;
            } else {
                $geohash .= self::BASE32[$ch];
                $bit = 0;
                $ch = 0;
            }
        }

        return $geohash;
    }
}

