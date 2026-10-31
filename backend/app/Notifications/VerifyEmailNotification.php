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
        return (new MailMessage)
            ->subject('Verifikasi Email - Radar Keliling')
            ->greeting('Halo!')
            ->line('Terima kasih telah mendaftar di Radar Keliling.')
            ->line('Kode verifikasi akun Anda adalah:')
            ->line("**{$this->token}**")
            ->line('Kode ini akan kedaluwarsa dalam 60 menit.')
            ->line('Jika Anda tidak merasa mendaftar di Radar Keliling, abaikan email ini.');
    }
}

