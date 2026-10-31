<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('demand_logs', function (Blueprint $table) {
            $table->id();
            $table->string('kategori_pencarian', 100)->nullable();
            $table->geometry('geom', subtype: 'point', srid: 4326);
            $table->timestampTz('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));

            $table->index('kategori_pencarian');
            $table->index('created_at');
        });

        // Spatial GIST index untuk pencarian spasial dan ST_SnapToGrid berkecepatan tinggi
        DB::statement('CREATE INDEX idx_demand_logs_geom ON demand_logs USING GIST (geom);');
    }

    public function down(): void
    {
        Schema::dropIfExists('demand_logs');
    }
};

