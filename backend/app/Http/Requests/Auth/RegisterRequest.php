<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $this->merge(['email' => strtolower(trim((string) $this->email))]);
    }

    public function rules(): array
    {
        return [
            'email' => ['required', 'email', 'max:254', 'unique:users,email'],
            'password' => ['required', 'string', Password::min(8)->letters()->numbers()],
            // Admin tidak bisa didaftarkan via endpoint publik
            'role' => ['required', 'in:buyer,merchant'],
        ];
    }
}

