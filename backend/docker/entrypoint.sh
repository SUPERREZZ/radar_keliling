#!/bin/sh
set -e

# Generate application key if not set
if [ -z "$APP_KEY" ]; then
    echo "Generating application key..."
    php artisan key:generate --force
fi

# Ensure storage and bootstrap/cache permissions
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# If custom command passed, run it
if [ "$#" -gt 0 ]; then
    exec "$@"
fi

# Default: wait for db, run migrations, start php-fpm and nginx
echo "Caching configuration..."
php artisan config:cache || true
php artisan route:cache || true

echo "Running migrations..."
php artisan migrate --force || true

echo "Linking public storage..."
php artisan storage:link --force || true

echo "Starting Laravel Scheduler in background..."
php artisan schedule:work > /dev/null 2>&1 &

echo "Starting PHP-FPM..."
php-fpm -D

echo "Starting Nginx..."
exec nginx -g "daemon off;"

