<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('calls', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->foreignUuid('buyer_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('merchant_id')->constrained('merchant_profiles')->cascadeOnDelete();
            $table->string('status', 20)->default('pending');
            $table->boolean('location_consent')->default(false);
            $table->timestampTz('consented_at')->nullable();
            $table->geography('buyer_location', subtype: 'point', srid: 4326)->nullable();
            $table->timestampTz('location_expires_at')->nullable()->index('idx_calls_location_expiry');
            $table->timestampTz('created_at')->default(DB::raw('NOW()'));

            $table->index(['buyer_id', 'created_at'], 'idx_calls_buyer_created');
            $table->index(['merchant_id', 'created_at'], 'idx_calls_merchant_created');
            $table->index(['buyer_id', 'merchant_id', 'created_at'], 'idx_calls_pair_created');
        });

        DB::statement("ALTER TABLE calls ADD CONSTRAINT chk_call_status CHECK (status IN ('pending', 'accept', 'accepted', 'answered', 'unanswered', 'cancelled', 'expired', 'completed'))");
    }

    public function down(): void
    {
        Schema::dropIfExists('calls');
    }
};

