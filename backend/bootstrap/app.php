<?php

use App\Exceptions\ApiException;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        channels: __DIR__.'/../routes/channels.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'merchant' => \App\Http\Middleware\EnsureUserIsMerchant::class,
            'admin' => \App\Http\Middleware\EnsureUserIsAdmin::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        // Format error standar sesuai kontrak README
        $exceptions->render(function (Throwable $e, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            return match (true) {
                $e instanceof ApiException => $e->render(),
                $e instanceof ValidationException => ApiException::response(
                    'VALIDATION_ERROR', 'Data yang dikirim tidak valid.', 422, $e->errors()
                ),
                $e instanceof AuthenticationException => ApiException::response(
                    'UNAUTHENTICATED', 'Silakan login terlebih dahulu.', 401
                ),
                $e instanceof AuthorizationException,
                $e instanceof AccessDeniedHttpException => ApiException::response(
                    'FORBIDDEN', 'Anda tidak memiliki izin untuk aksi ini.', 403
                ),
                $e instanceof ModelNotFoundException,
                $e instanceof NotFoundHttpException => ApiException::response(
                    'NOT_FOUND', 'Resource tidak ditemukan.', 404
                ),
                $e instanceof ThrottleRequestsException => ApiException::response(
                    'RATE_LIMITED', 'Terlalu banyak permintaan. Coba lagi nanti.', 429
                ),
                $e instanceof HttpExceptionInterface => ApiException::response(
                    'HTTP_ERROR', $e->getMessage() ?: 'Permintaan tidak dapat diproses.', $e->getStatusCode()
                ),
                default => config('app.debug') ? null : ApiException::response(
                    'SERVER_ERROR', 'Terjadi kesalahan pada server.', 500
                ),
            };
        });
    })->create();
