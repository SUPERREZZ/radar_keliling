<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    protected static ?string $password;

    public function definition(): array
    {
        return [
            'email' => fake()->unique()->safeEmail(),
            'password' => static::$password ??= Hash::make('password'),
            'role' => User::ROLE_BUYER,
            'email_verified' => true,
        ];
    }

    public function unverified(): static
    {
        return $this->state(fn () => ['email_verified' => false]);
    }

    public function merchant(): static
    {
        return $this->state(fn () => ['role' => User::ROLE_MERCHANT]);
    }

    public function admin(): static
    {
        return $this->state(fn () => ['role' => User::ROLE_ADMIN]);
    }
}
