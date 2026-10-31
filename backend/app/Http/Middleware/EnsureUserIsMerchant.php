<?php

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserIsMerchant
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->isMerchant()) {
            throw new ApiException('FORBIDDEN', 'Hanya akun pedagang yang dapat mengakses fitur ini.', 403);
        }

        return $next($request);
    }
}

