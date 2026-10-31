<?php

namespace App\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;

/**
 * Error bisnis dengan format standar:
 * { "error": { "code": "...", "message": "...", "details": {} } }
 */
class ApiException extends Exception
{
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly int $status = 400,
        public readonly array $details = [],
    ) {
        parent::__construct($message);
    }

    public function render(): JsonResponse
    {
        return self::response($this->errorCode, $this->getMessage(), $this->status, $this->details);
    }

    public static function response(string $code, string $message, int $status, array $details = []): JsonResponse
    {
        return response()->json([
            'error' => [
                'code' => $code,
                'message' => $message,
                'details' => (object) $details,
            ],
        ], $status);
    }
}
