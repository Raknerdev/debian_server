#!/bin/bash

# Colores para la salida
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verificar privilegios de root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${BLUE}Por favor, ejecuta como root o usando sudo.${NC}"
  exit 1
fi

echo -e "${BLUE}>>> 1. Preparando Repositorios Oficiales (Redis & Node.js)...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update && apt install -y lsb-release curl gpg ca-certificates --no-install-recommends

# Repositorio oficial de Redis
curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list

# Repositorio oficial de Node.js (LTS)
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -

echo -e "${BLUE}>>> 2. Instalando Stack de Alto Rendimiento...${NC}"
apt update
apt install -y nginx redis-server nodejs unzip git g++ make --no-install-recommends \
    php-fpm php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-pgsql php-redis

# --- 3. INSTALACIÓN SEGURA DE COMPOSER ---
echo -e "${BLUE}>>> Instalando Composer con verificación de integridad...${NC}"
EXPECTED_CHECKSUM="$(php -r 'copy("https://composer.github.io/installer.sig", "php://stdout");')"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    echo -e "${BLUE}ERROR: Instalador de Composer corrupto${NC}"
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --quiet
rm composer-setup.php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# --- 4. OPTIMIZACIÓN DEL KERNEL (TCP/IP) ---
echo -e "${BLUE}>>> Ajustando parámetros de red del Kernel...${NC}"
cat <<EOT >> /etc/sysctl.conf
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 15
EOT
sysctl -p

# --- 5. OPTIMIZACIÓN DEL SISTEMA (ULIMIT) ---
cat <<EOT >> /etc/security/limits.conf
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOT
echo "session required pam_limits.so" >> /etc/pam.d/common-session

# --- 6. OPTIMIZACIÓN REDIS ---
echo -e "${BLUE}>>> Sintonizando Redis para 2k usuarios...${NC}"
sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
sed -i 's/^# maxclients 10000/maxclients 20000/' /etc/redis/redis.conf
sed -i 's/^# maxmemory <bytes>/maxmemory 2gb/' /etc/redis/redis.conf
sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
sed -i 's/^tcp-backlog 511/tcp-backlog 2048/' /etc/redis/redis.conf

mkdir -p /etc/systemd/system/redis-server.service.d/
echo -e "[Service]\nLimitNOFILE=65535" > /etc/systemd/system/redis-server.service.d/limits.conf
systemctl daemon-reload
systemctl restart redis-server

# --- 7. OPTIMIZACIÓN PHP-FPM & OPCACHE ---
PHP_VAL=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
POOL_FILE="/etc/php/$PHP_VAL/fpm/pool.d/www.conf"
PHP_INI="/etc/php/$PHP_VAL/fpm/php.ini"

echo -e "${BLUE}>>> Aplicando sintonía fina a PHP-FPM y OPcache...${NC}"
# Pool Estático
sed -i 's/^pm = .*/pm = static/' $POOL_FILE
sed -i 's/^pm.max_children = .*/pm.max_children = 250/' $POOL_FILE
sed -i 's/^;pm.max_requests = .*/pm.max_requests = 1000/' $POOL_FILE

# Opcache y Límites de memoria
sed -i 's/memory_limit = .*/memory_limit = 512M/' $PHP_INI
sed -i 's/;opcache.enable=.*/opcache.enable=1/' $PHP_INI
sed -i 's/;opcache.memory_consumption=.*/opcache.memory_consumption=256/' $PHP_INI
sed -i 's/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=20000/' $PHP_INI
sed -i 's/;opcache.validate_timestamps=.*/opcache.validate_timestamps=0/' $PHP_INI

# --- 8. NGINX & NGINX-UI ---
echo -e "${BLUE}>>> Optimizando Nginx e instalando Nginx-UI...${NC}"
sed -i 's/worker_connections .*/worker_connections 10240;/' /etc/nginx/nginx.conf
sed -i '/events {/a \    multi_accept on;' /etc/nginx/nginx.conf

systemctl restart php$PHP_VAL-fpm
systemctl restart nginx

bash -c "$(curl -L https://cloud.nginxui.com/install.sh)" @ install

echo -e "${GREEN}>>> SERVIDOR OPTIMIZADO COMPLETADO CON ÉXITO.${NC}"