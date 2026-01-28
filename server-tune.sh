#!/bin/bash

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
  echo -e "${BLUE}Por favor, ejecuta como root.${NC}"
  exit 1
fi

# --- 1. OPTIMIZACIÓN DEL KERNEL (TCP/IP) ---
echo -e "${BLUE}>>> Ajustando parámetros de red del Kernel...${NC}"
cat <<EOT > /etc/sysctl.d/99-laravel-tune.conf
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 15
EOT
sysctl --system

# --- 2. OPTIMIZACIÓN DEL SISTEMA (ULIMIT) ---
echo -e "${BLUE}>>> Ajustando límites de archivos...${NC}"
cat <<EOT >> /etc/security/limits.conf
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOT
grep -q "pam_limits.so" /etc/pam.d/common-session || echo "session required pam_limits.so" >> /etc/pam.d/common-session

# --- 3. OPTIMIZACIÓN REDIS ---
echo -e "${BLUE}>>> Sintonizando Redis...${NC}"
sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
sed -i 's/^# maxclients 10000/maxclients 20000/' /etc/redis/redis.conf
sed -i 's/^# maxmemory <bytes>/maxmemory 2gb/' /etc/redis/redis.conf
sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
sed -i 's/^tcp-backlog 511/tcp-backlog 2048/' /etc/redis/redis.conf

mkdir -p /etc/systemd/system/redis-server.service.d/
echo -e "[Service]\nLimitNOFILE=65535" > /etc/systemd/system/redis-server.service.d/limits.conf
systemctl daemon-reload
systemctl restart redis-server

# --- 4. OPTIMIZACIÓN PHP-FPM & OPCACHE ---
PHP_VAL=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
POOL_FILE="/etc/php/$PHP_VAL/fpm/pool.d/www.conf"
PHP_INI="/etc/php/$PHP_VAL/fpm/php.ini"

echo -e "${BLUE}>>> Aplicando sintonía fina a PHP-FPM y OPcache...${NC}"
sed -i 's/^pm = .*/pm = static/' $POOL_FILE
sed -i 's/^pm.max_children = .*/pm.max_children = 250/' $POOL_FILE
sed -i 's/^;pm.max_requests = .*/pm.max_requests = 1000/' $POOL_FILE

sed -i 's/memory_limit = .*/memory_limit = 512M/' $PHP_INI
sed -i 's/;opcache.enable=.*/opcache.enable=1/' $PHP_INI
sed -i 's/;opcache.memory_consumption=.*/opcache.memory_consumption=256/' $PHP_INI
sed -i 's/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=20000/' $PHP_INI
sed -i 's/;opcache.validate_timestamps=.*/opcache.validate_timestamps=0/' $PHP_INI

# --- 5. NGINX TUNING ---
echo -e "${BLUE}>>> Optimizando Nginx y Afinidad de CPU...${NC}"
CPU_CORES=$(nproc)

sed -i "s/worker_processes.*/worker_processes $CPU_CORES;/" /etc/nginx/nginx.conf
if ! grep -q "worker_cpu_affinity" /etc/nginx/nginx.conf; then
    sed -i "/worker_processes/a worker_cpu_affinity auto;" /etc/nginx/nginx.conf
fi

sed -i '/worker_rlimit_nofile/d' /etc/nginx/nginx.conf
sed -i "/worker_processes/a worker_rlimit_nofile 30000;" /etc/nginx/nginx.conf

sed -i 's/worker_connections .*/worker_connections 10240;/' /etc/nginx/nginx.conf

# Reset multi_accept a estado comentado para mejor balanceo
sed -i '/multi_accept on;/d' /etc/nginx/nginx.conf
if ! grep -q "multi_accept" /etc/nginx/nginx.conf; then
    sed -i '/events {/a \    # multi_accept on;' /etc/nginx/nginx.conf
fi

systemctl restart php$PHP_VAL-fpm
systemctl restart nginx

echo -e "${GREEN}>>> CONFIGURACIÓN Y TUNING COMPLETADOS.${NC}"