#!/bin/bash
# Installs the web server, PHP, and WordPress automatically
dnf update -y
dnf install -y httpd php php-fpm php-mysqlnd php-json php-gd php-mbstring php-xml php-intl wget mariadb105
systemctl enable --now httpd php-fpm
cd /tmp && wget -q https://wordpress.org/latest.tar.gz && tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i "s/database_name_here/wordpress/; s/username_here/admin/" /var/www/html/wp-config.php
chown -R apache:apache /var/www/html

# Helper command 1: connect WordPress to your RDS database
cat > /usr/bin/connect-db << 'EOF'
#!/bin/bash
read -p "Paste your RDS endpoint, then press Enter: " DB_HOST
read -s -p "Type your database password, then press Enter (it stays hidden): " DB_PASS
echo
echo "Testing the connection to your database..."
if mysql -h "$DB_HOST" -u admin -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS wordpress;" 2>/tmp/db-error.txt; then
  sed -i "s/password_here/$DB_PASS/; s/'localhost'/'$DB_HOST'/" /var/www/html/wp-config.php
  echo "SUCCESS! WordPress is connected to RDS. Go back to your browser and refresh."
else
  echo "NOT CONNECTED. Check your endpoint and password, then run: sudo connect-db"
  cat /tmp/db-error.txt
fi
EOF

# Helper command 2: show the posts stored in RDS
cat > /usr/bin/show-posts << 'EOF'
#!/bin/bash
H=$(grep "'DB_HOST'" /var/www/html/wp-config.php | cut -d"'" -f4)
P=$(grep "'DB_PASSWORD'" /var/www/html/wp-config.php | cut -d"'" -f4)
mysql -h "$H" -u admin -p"$P" wordpress -e "SELECT ID, post_title AS 'Posts stored in RDS' FROM wp_posts WHERE post_status='publish';"
EOF
chmod +x /usr/bin/connect-db /usr/bin/show-posts
