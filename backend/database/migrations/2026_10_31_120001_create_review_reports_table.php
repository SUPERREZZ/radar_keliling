<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('review_reports', function (Blueprint $table) {
            $table->uuid('id')->primary()->default(DB::raw('gen_random_uuid()'));
            $table->uuid('review_id');
            $table->uuid('reporter_id');
            $table->text('reason');
            $table->string('status', 20)->default('pending');
            $table->timestamps();

            $table->foreign('review_id')->references('id')->on('reviews')->onDelete('cascade');
            $table->foreign('reporter_id')->references('id')->on('users')->onDelete('cascade');

            $table->index('review_id');
            $table->index('reporter_id');
            $table->index('status');
        });

        DB::statement("ALTER TABLE review_reports ADD CONSTRAINT check_review_reports_status CHECK (status IN ('pending', 'reviewed', 'dismissed'));");
    }

    public function down(): void
    {
        Schema::dropIfExists('review_reports');
    }
};

