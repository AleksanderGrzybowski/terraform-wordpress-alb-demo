#!/bin/bash

echo "Taken from https://ubuntu.com/tutorials/install-and-configure-wordpress#1-overview"

sudo apt update
sudo apt-get -y install apache2 ghostscript libapache2-mod-php php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip

sudo mkdir -p /srv/www
sudo chown www-data: /srv/www
curl https://wordpress.org/latest.tar.gz | sudo -u www-data tar zx -C /srv/www

cat > /etc/apache2/sites-available/wordpress.conf <<EOF
<VirtualHost *:80>
    DocumentRoot /srv/www/wordpress
    <Directory /srv/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /srv/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF

sudo a2ensite wordpress
sudo a2enmod rewrite
sudo a2dissite 000-default
sudo systemctl restart apache2

sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/localhost/${database_host}/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/database_name_here/${database_name}/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/username_here/${database_username}/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/password_here/${database_password}/' /srv/www/wordpress/wp-config.php
