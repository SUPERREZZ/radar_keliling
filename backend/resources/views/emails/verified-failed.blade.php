<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verifikasi Gagal - Radar Keliling</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body {
            background-color: #F6F8F7;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            color: #1A1A1A;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 24px 16px;
        }
        .card {
            background: #FFFFFF;
            max-width: 480px;
            width: 100%;
            border-radius: 24px;
            border: 1px solid #E5E7EB;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.05);
            overflow: hidden;
            text-align: center;
        }
        .header {
            background: linear-gradient(135deg, #DC2626 0%, #991B1B 100%);
            padding: 36px 24px;
            position: relative;
        }
        .icon-circle {
            width: 80px;
            height: 80px;
            background: #FFFFFF;
            border-radius: 50%;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
            margin-bottom: 12px;
        }
        .icon-circle svg {
            width: 44px;
            height: 44px;
            color: #DC2626;
        }
        .brand-name {
            color: #FFFFFF;
            font-size: 20px;
            font-weight: 800;
            letter-spacing: -0.5px;
        }
        .content {
            padding: 36px 28px 40px;
        }
        .badge {
            display: inline-block;
            background-color: #FEE2E2;
            color: #DC2626;
            font-size: 13px;
            font-weight: 700;
            padding: 6px 14px;
            border-radius: 9999px;
            margin-bottom: 16px;
        }
        h1 {
            font-size: 24px;
            font-weight: 800;
            color: #1A1A1A;
            margin-bottom: 12px;
            letter-spacing: -0.5px;
        }
        p {
            font-size: 15px;
            line-height: 1.6;
            color: #4B5563;
            margin-bottom: 24px;
        }
        .btn {
            display: inline-block;
            background-color: #00875A;
            color: #FFFFFF;
            text-decoration: none;
            font-weight: 700;
            font-size: 15px;
            padding: 14px 28px;
            border-radius: 12px;
            box-shadow: 0 4px 14px rgba(0, 135, 90, 0.3);
            transition: transform 0.15s ease, background-color 0.15s ease;
        }
        .btn:hover {
            background-color: #00704A;
            transform: translateY(-1px);
        }
        .footer-note {
            margin-top: 24px;
            font-size: 12px;
            color: #9CA3AF;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="header">
            <div style="margin-bottom: 14px;">
                <img src="{{ asset('images/logo.png') }}" width="64" height="64" alt="Radar Keliling" style="border-radius: 16px; box-shadow: 0 4px 14px rgba(0,0,0,0.2); border: 2px solid rgba(255,255,255,0.4);">
            </div>
            <div class="icon-circle">
                <svg fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
            </div>
            <div class="brand-name">Radar Keliling</div>
        </div>

        <div class="content">
            <span class="badge">Verifikasi Tidak Berhasil</span>
            <h1>Tautan Tidak Valid atau Kedaluwarsa</h1>
            <p>
                {{ $message ?? 'Tautan verifikasi telah kedaluwarsa atau sudah pernah digunakan sebelumnya.' }}
            </p>
            <p>
                Buka kembali aplikasi <strong>Radar Keliling</strong> di smartphone Anda untuk meminta tautan verifikasi baru melalui menu login.
            </p>
            <a href="radarkeliling://" class="btn">Kembali ke Aplikasi</a>
            <div class="footer-note">
                Buka aplikasi langsung dari beranda smartphone Anda jika tautan di atas tidak merespons.
            </div>
        </div>
    </div>
</body>
</html>

