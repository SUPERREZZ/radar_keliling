<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class VerifyEmailNotification extends Notification
{
    use Queueable;

    public function __construct(public readonly string $token)
    {
    }

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $verifyUrl = url('/api/v1/auth/verify-email?token='.urlencode($this->token));

        return (new MailMessage)
            ->subject('Verifikasi Email - Radar Keliling')
            ->greeting('Halo!')
            ->line('Terima kasih telah mendaftar di Radar Keliling.')
            ->action('Verifikasi Email Sekarang', $verifyUrl)
            ->line('Atau gunakan kode verifikasi akun Anda:')
            ->line("**{$this->token}**")
            ->line('Tautan dan kode ini akan kedaluwarsa dalam 60 menit.')
            ->line('Jika Anda tidak merasa mendaftar di Radar Keliling, abaikan email ini.');
    }
}

