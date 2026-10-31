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
            $table->geography('current_location', subtype: 'point', srid: 4326);
            $table->float('gps_accuracy_m');
            $table->timestampTz('last_updated_at')->index('idx_merchant_locations_updated');

            $table->foreign('merchant_id', 'fk_location_merchant')
                ->references('id')->on('merchant_profiles')
                ->cascadeOnDelete();
        });

        DB::statement('ALTER TABLE merchant_locations ADD CONSTRAINT chk_gps_accuracy CHECK (gps_accuracy_m >= 0)');
        DB::statement('CREATE INDEX idx_merchant_locations_gist ON merchant_locations USING GIST (current_location)');
    }

    public function down(): void
    {
        Schema::dropIfExists('merchant_locations');
    }
};

