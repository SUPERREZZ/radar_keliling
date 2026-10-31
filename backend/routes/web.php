<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    if (config('app.env') === 'production' || app()->environment('production')) {
        return response()->json([
            'name' => config('app.name'),
            'status' => 'online',
        ]);
    }

    return redirect('/docs');
});

Route::get('/docs', function () {
    abort_if(config('app.env') === 'production' || app()->environment('production'), 404);

    return view('swagger');
});

Route::redirect('/swagger', '/docs');
