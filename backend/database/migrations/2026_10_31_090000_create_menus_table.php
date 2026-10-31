<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('menus', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->foreignUuid('merchant_id')->constrained('merchant_profiles')->cascadeOnDelete();
            $table->string('name', 100);
            $table->text('description')->nullable();
            $table->decimal('price', 12, 2);
            $table->boolean('is_available')->default(true);
            $table->timestampsTz();
        });

        DB::statement('ALTER TABLE menus ADD CONSTRAINT chk_menu_price CHECK (price >= 0)');
        DB::statement('ALTER TABLE menus ADD CONSTRAINT chk_menu_name CHECK (LENGTH(TRIM(name)) > 0)');
    }

    public function down(): void
    {
        Schema::dropIfExists('menus');
    }
};

