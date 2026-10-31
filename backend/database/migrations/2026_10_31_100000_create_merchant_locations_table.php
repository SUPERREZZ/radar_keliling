<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('merchant_locations', function (Blueprint $table) {
            $table->uuid('merchant_id')->primary();
            // MySQL spatial POINT type (lat, lng)
            $table->point('current_location')->spatialIndex();
            $table->float('gps_accuracy_m')->unsigned();
            $table->timestamp('last_updated_at')->index('idx_merchant_locations_updated');

            $table->foreign('merchant_id', 'fk_location_merchant')
                ->references('id')->on('merchant_profiles')
                ->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('merchant_locations');
    }
};

