<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reviews', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->uuid('call_id')->unique();
            $table->uuid('buyer_id');
            $table->uuid('merchant_id');
            $table->unsignedSmallInteger('rating');
            $table->text('review_text')->nullable();
            $table->string('moderation_status', 20)->default('visible');
            $table->timestamps();

            $table->foreign('call_id')->references('id')->on('calls')->onDelete('cascade');
            $table->foreign('buyer_id')->references('id')->on('users')->onDelete('cascade');
            $table->foreign('merchant_id')->references('id')->on('merchant_profiles')->onDelete('cascade');

            $table->index('merchant_id');
            $table->index('buyer_id');
            $table->index('moderation_status');
        });

        DB::statement('ALTER TABLE reviews ADD CONSTRAINT check_reviews_rating CHECK (rating >= 1 AND rating <= 5);');
        DB::statement("ALTER TABLE reviews ADD CONSTRAINT check_reviews_moderation_status CHECK (moderation_status IN ('visible', 'hidden'));");
    }

    public function down(): void
    {
        Schema::dropIfExists('reviews');
    }
};