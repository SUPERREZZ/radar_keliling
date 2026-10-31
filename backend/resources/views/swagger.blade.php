<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ config('app.name') }} - Swagger API Documentation</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.18.2/swagger-ui.css">
    <link rel="icon" type="image/png" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.18.2/favicon-32x32.png" sizes="32x32" />
    <style>
        html {
            box-sizing: border-box;
            overflow: -moz-scrollbars-vertical;
            overflow-y: scroll;
        }
        *, *:before, *:after {
            box-sizing: inherit;
        }
        body {
            margin: 0;
            background: #fafafa;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
        }
        .topbar {
            background-color: #1e293b !important;
            padding: 10px 0;
        }
        .topbar-wrapper .link {
            display: flex;
            align-items: center;
            gap: 12px;
            color: #ffffff;
            font-size: 18px;
            font-weight: 700;
            text-decoration: none;
        }
        .topbar-wrapper img {
            height: 36px;
        }
        .custom-badge {
            background: #10b981;
            color: white;
            font-size: 11px;
            padding: 3px 8px;
            border-radius: 9999px;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="topbar">
        <div class="swagger-ui">
            <div class="wrapper topbar-wrapper">
                <a href="/docs" class="link">
                    <span>🛰️ Radar Keliling API</span>
                    <span class="custom-badge">Swagger UI</span>
                </a>
            </div>
        </div>
    </div>

    <div id="swagger-ui"></div>

    <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.18.2/swagger-ui-bundle.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.18.2/swagger-ui-standalone-preset.js"></script>
    <script>
        window.onload = function() {
            window.ui = SwaggerUIBundle({
                url: "/docs/api.json",
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "BaseLayout",
                persistAuthorization: true,
                displayRequestDuration: true,
                filter: true,
                tryItOutEnabled: true,
            });
        };
    </script>
</body>
</html>

