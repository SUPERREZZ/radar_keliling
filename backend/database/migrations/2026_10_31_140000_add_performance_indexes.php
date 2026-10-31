<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('merchant_profiles', function (Blueprint $table) {
            $table->index('is_selling', 'idx_merchant_profiles_is_selling');
        });

        Schema::table('menus', function (Blueprint $table) {
            $table->index(['merchant_id', 'is_available'], 'idx_menus_merchant_available');
            $table->index(['merchant_id', 'created_at'], 'idx_menus_merchant_created');
        });

        Schema::table('menu_photos', function (Blueprint $table) {
            $table->index('menu_id', 'idx_menu_photos_menu_id');
        });

        Schema::table('calls', function (Blueprint $table) {
            $table->index(['merchant_id', 'status', 'created_at'], 'idx_calls_merchant_status_created');
            $table->index(['buyer_id', 'status', 'created_at'], 'idx_calls_buyer_status_created');
        });

        DB::statement('CREATE INDEX IF NOT EXISTS idx_calls_buyer_location_gist ON calls USING GIST (buyer_location)');

        Schema::table('reviews', function (Blueprint $table) {
            $table->index(['merchant_id', 'moderation_status', 'rating'], 'idx_reviews_merchant_visible_rating');
        });

        Schema::table('demand_logs', function (Blueprint $table) {
            $table->index(['created_at', 'kategori_pencarian'], 'idx_demand_logs_created_category');
        });
    }

    public function down(): void
    {
        Schema::table('demand_logs', function (Blueprint $table) {
            $table->dropIndex('idx_demand_logs_created_category');
        });

        Schema::table('reviews', function (Blueprint $table) {
            $table->dropIndex('idx_reviews_merchant_visible_rating');
        });

        DB::statement('DROP INDEX IF EXISTS idx_calls_buyer_location_gist');

        Schema::table('calls', function (Blueprint $table) {
            $table->dropIndex('idx_calls_merchant_status_created');
            $table->dropIndex('idx_calls_buyer_status_created');
        });

        Schema::table('menu_photos', function (Blueprint $table) {
            $table->dropIndex('idx_menu_photos_menu_id');
        });

        Schema::table('menus', function (Blueprint $table) {
            $table->dropIndex('idx_menus_merchant_available');
            $table->dropIndex('idx_menus_merchant_created');
        });

        Schema::table('merchant_profiles', function (Blueprint $table) {
            $table->dropIndex('idx_merchant_profiles_is_selling');
        });
    }
};

