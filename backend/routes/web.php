<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect('/docs/api');
});

Route::redirect('/docs', '/docs/api');
Route::redirect('/swagger', '/docs/api');
