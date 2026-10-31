<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>Verifikasi Email - Radar Keliling</title>
    <!--[if mso]>
    <style type="text/css">
        body, table, td, a { font-family: Arial, sans-serif !important; }
    </style>
    <![endif]-->
    <style>
        body {
            margin: 0;
            padding: 0;
            background-color: #F6F8F7;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            color: #1A1A1A;
            -webkit-font-smoothing: antialiased;
        }
        table {
            border-collapse: collapse;
        }
        .wrapper {
            width: 100%;
            table-layout: fixed;
            background-color: #F6F8F7;
            padding: 40px 16px;
        }
        .container {
            max-width: 580px;
            margin: 0 auto;
            background-color: #FFFFFF;
            border-radius: 20px;
            border: 1px solid #E5E7EB;
            overflow: hidden;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.04);
        }
        .header {
            background: linear-gradient(135deg, #00875A 0%, #005C3B 100%);
            padding: 32px 28px;
            text-align: center;
        }
        .header-logo {
            display: inline-flex;
            align-items: center;
            color: #FFFFFF;
            font-size: 24px;
            font-weight: 800;
            letter-spacing: -0.5px;
            text-decoration: none;
        }
        .header-badge {
            display: inline-block;
            margin-top: 10px;
            background-color: rgba(255, 255, 255, 0.2);
            color: #E6F5EF;
            font-size: 12px;
            font-weight: 600;
            padding: 4px 12px;
            border-radius: 9999px;
            letter-spacing: 0.5px;
        }
        .content {
            padding: 36px 32px;
        }
        .title {
            font-size: 22px;
            font-weight: 800;
            color: #1A1A1A;
            margin: 0 0 12px 0;
            letter-spacing: -0.3px;
        }
        .paragraph {
            font-size: 15px;
            line-height: 1.6;
            color: #4B5563;
            margin: 0 0 24px 0;
        }
        .button-wrapper {
            text-align: center;
            margin: 30px 0;
        }
        .button {
            display: inline-block;
            background-color: #00875A;
            color: #FFFFFF !important;
            font-size: 15px;
            font-weight: 700;
            text-decoration: none;
            padding: 14px 32px;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0, 135, 90, 0.25);
        }
        .code-box {
            background-color: #E6F5EF;
            border: 1px dashed #00875A;
            border-radius: 14px;
            padding: 20px;
            text-align: center;
            margin: 28px 0;
        }
        .code-title {
            font-size: 12px;
            text-transform: uppercase;
            font-weight: 700;
            color: #005C3B;
            letter-spacing: 1px;
            margin: 0 0 8px 0;
        }
        .otp-code {
            font-family: 'Courier New', Courier, monospace;
            font-size: 34px;
            font-weight: 800;
            color: #005C3B;
            letter-spacing: 8px;
            margin: 0;
        }
        .expiry-note {
            display: flex;
            align-items: center;
            background-color: #FFFBEB;
            border-left: 4px solid #F59E0B;
            padding: 12px 16px;
            border-radius: 8px;
            font-size: 13px;
            color: #92400E;
            margin: 24px 0 0 0;
        }
        .footer {
            background-color: #FAFAF9;
            border-top: 1px solid #F3F4F6;
            padding: 24px 32px;
            text-align: center;
            font-size: 12px;
            color: #9CA3AF;
            line-height: 1.5;
        }
        .footer a {
            color: #00875A;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="wrapper">
        <table role="presentation" width="100%" border="0" cellspacing="0" cellpadding="0">
            <tr>
                <td align="center">
                    <div class="container">
                        <!-- Header -->
                        <div class="header">
                            <div class="header-logo">
                                🛰️ Radar Keliling
                            </div>
                            <br>
                            <span class="header-badge">VERIFIKASI AKUN</span>
                        </div>

                        <!-- Content -->
                        <div class="content">
                            <h1 class="title">Halo! 👋</h1>
                            <p class="paragraph">
                                Terima kasih telah bergabung di <strong>Radar Keliling</strong>. Satu langkah lagi untuk mulai menemukan atau menjajakan kuliner keliling favorit secara <em>real-time</em> di sekitarmu!
                            </p>

                            <!-- Primary Button Action -->
                            <div class="button-wrapper">
                                <a href="{{ $verifyUrl }}" target="_blank" class="button">
                                    Verifikasi Email Sekarang
                                </a>
                            </div>

                            <!-- Or Enter OTP in Mobile App -->
                            <div class="code-box">
                                <div class="code-title">Atau Masukkan Kode Verifikasi di Aplikasi</div>
                                <div class="otp-code">{{ $token }}</div>
                            </div>

                            <!-- Expiry Note -->
                            <div class="expiry-note">
                                ⏰ Tautan dan kode ini berlaku selama <strong>60 menit</strong>.
                            </div>

                            <p class="paragraph" style="margin-top: 24px; font-size: 13px; color: #9CA3AF;">
                                Jika Anda tidak merasa mendaftar akun di Radar Keliling, silakan abaikan email ini dengan aman.
                            </p>
                        </div>

                        <!-- Footer -->
                        <div class="footer">
                            <p style="margin: 0 0 6px 0;">
                                <strong>Radar Keliling</strong> — Real-Time Geospatial Street Food Radar
                            </p>
                            <p style="margin: 0;">
                                Email ini dikirimkan secara otomatis, mohon untuk tidak membalas langsung ke alamat ini.
                            </p>
                        </div>
                    </div>
                </td>
            </tr>
        </table>
    </div>
</body>
</html>

