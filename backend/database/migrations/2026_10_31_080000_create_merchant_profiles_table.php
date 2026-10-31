<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('merchant_profiles', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->foreignUuid('user_id')->unique('uq_merchant_profile_user')
                ->constrained('users')
                ->cascadeOnDelete();
            $table->string('business_name', 100);
            $table->text('description')->nullable();
            $table->text('profile_photo_path')->nullable();
            $table->boolean('is_selling')->default(false);
            $table->timestampsTz();
        });

        DB::statement('ALTER TABLE merchant_profiles ADD CONSTRAINT chk_merchant_business_name CHECK (LENGTH(TRIM(business_name)) > 0)');
    }

    public function down(): void
    {
        Schema::dropIfExists('merchant_profiles');
    }
};

