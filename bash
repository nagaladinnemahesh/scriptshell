#!/bin/bash

# Get server IP address
SERVER_IP=$(curl -sS ifconfig.me)

# Update package lists
sudo apt update
sudo apt install nginx -y

# Check available UFW application profiles
sudo ufw app list

# Allow connections to Nginx HTTP
sudo ufw allow 'Nginx HTTP'

# Install MySQL server
sudo apt update
sudo apt install mysql-server -y

# Run MySQL secure installation
sudo mysql_secure_installation <<EOF
Y
2
y
y
y
y
EOF

# Install PHP and PHP modules
sudo apt update
sudo apt install php8.1-fpm php-mysql -y

# Update package manager cache
sudo apt update

# Install required packages
sudo apt install php-cli unzip -y

# Download Composer installer
cd ~
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php

# Get the SHA-384 hash for verification
HASH=$(curl -sS https://composer.github.io/installer.sig)

echo $HASH

# Verify the downloaded installer using PHP
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('/tmp/composer-setup.php'); } echo PHP_EOL;"


# Install Composer globally
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Test installation
composer --no-interaction

# Update package manager cache
sudo apt update

# Install required PHP modules
sudo apt install php-mbstring php-xml php-bcmath php-curl -y

# Connect to MySQL console
sudo mysql <<EOF

# Create database if not exists
CREATE DATABASE IF NOT EXISTS laravel;

# Create user and grant privileges
CREATE USER 'mahesh'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Mahesh@123';
GRANT ALL ON laravel.* TO 'mahesh'@'localhost';

# Exit MySQL console
exit
EOF

# Create a directory for Laravel if not exists
sudo mkdir -p /var/www/laravel

# Clone the Laravel project from Git
cd /var/www/laravel/
git clone https://github.com/nagaladinnemahesh/laraveldeploy.git

# Navigate into the Laravel project directory
cd laraveldeploy

# Install Laravel dependencies
composer install --no-interaction

sudo cp .env.example .env

# Define variables
APP_URL="http://$SERVER_IP"
DB_DATABASE="laravel"
DB_USERNAME="mahesh"
DB_PASSWORD="Mahesh@123"

# Update values in the .env file
sed -i "s|^APP_URL=.*|APP_URL=$APP_URL|" .env
sed -i "s|^DB_DATABASE=.*|DB_DATABASE=$DB_DATABASE|" .env
sed -i "s|^DB_USERNAME=.*|DB_USERNAME=$DB_USERNAME|" .env
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" .env

# Change ownership of storage and bootstrap/cache directories
sudo chown -R www-data:www-data /var/www/laravel/laraveldeploy/storage
sudo chown -R www-data:www-data /var/www/laravel/laraveldeploy/bootstrap/cache
sudo chmod -R 775 /var/www/laravel/laraveldeploy/storage

# Create a new Nginx server block configuration file
sudo tee /etc/nginx/sites-available/laraveldeploy >/dev/null <<EOF
server {
    listen 80;
    server_name $SERVER_IP; # Use the dynamically fetched IP address
    root /var/www/laravel/laraveldeploy/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";

    index index.html index.htm index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

# Create a symbolic link to enable the site
sudo ln -s /etc/nginx/sites-available/laraveldeploy /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Reload Nginx to apply changes
sudo systemctl reload nginx

# Generate application key
php artisan key:generate

sudo systemctl reload nginx

echo "Setup completed successfully!"
