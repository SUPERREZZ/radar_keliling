<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('fcm_tokens', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('token')->unique('uq_fcm_token');
            $table->string('device_type', 20)->nullable()->default('android');
            $table->timestampTz('last_seen_at')->nullable();
            $table->timestampsTz();

            $table->index('user_id', 'idx_fcm_tokens_user');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('fcm_tokens');
    }
};

