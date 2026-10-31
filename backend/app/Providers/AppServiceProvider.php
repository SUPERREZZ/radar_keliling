<?php

namespace App\Providers;

use App\Models\User;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Sembunyikan dokumentasi API jika environment adalah production
        Gate::define('viewApiDocs', function (?User $user = null) {
            return config('app.env') !== 'production' && ! app()->environment('production');
        });
    }
}
