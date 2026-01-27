#!/bin/bash

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
  echo "Ejecuta como root."
  exit 1
fi

echo -e "${BLUE}>>> 1. Actualizando e instalando Stack Base...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y
apt install -y nginx redis-server unzip curl git --no-install-recommends \
    php-fpm php-cli php-mbstring php-xml php-bcmath php-curl php-zip php-pgsql php-redis

# --- OPTIMIZACIÓN DEL SISTEMA (ULIMIT) ---
echo -e "${BLUE}>>> 2. Ajustando límites de archivos del sistema...${NC}"
cat <<EOT >> /etc/security/limits.conf
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOT
echo "session required pam_limits.so" >> /etc/pam.d/common-session

# --- OPTIMIZACIÓN NGINX (Conexiones) ---
echo -e "${BLUE}>>> 3. Optimizando Nginx para concurrencia...${NC}"
sed -i 's/worker_connections .*/worker_connections 10240;/' /etc/nginx/nginx.conf
# Asegurar que multi_accept esté activo para manejar múltiples conexiones a la vez
sed -i '/events {/a \    multi_accept on;' /etc/nginx/nginx.conf

# --- OPTIMIZACIÓN REDIS ---
sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
systemctl restart redis-server

# --- OPTIMIZACIÓN PHP-FPM ---
PHP_VAL=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
POOL_FILE="/etc/php/$PHP_VAL/fpm/pool.d/www.conf"
PHP_INI="/etc/php/$PHP_VAL/fpm/php.ini"

echo -e "${BLUE}>>> 4. Aplicando sintonía fina a PHP $PHP_VAL...${NC}"

# Configuración de procesos Estática (Ideal para 2k usuarios con RAM suficiente)
sed -i 's/^pm = .*/pm = static/' $POOL_FILE
sed -i 's/^pm.max_children = .*/pm.max_children = 250/' $POOL_FILE
sed -i 's/^;pm.max_requests = .*/pm.max_requests = 1000/' $POOL_FILE

# Opcache y Límites de memoria
sed -i 's/memory_limit = .*/memory_limit = 512M/' $PHP_INI
sed -i 's/;opcache.enable=.*/opcache.enable=1/' $PHP_INI
sed -i 's/;opcache.memory_consumption=.*/opcache.memory_consumption=256/' $PHP_INI
sed -i 's/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=20000/' $PHP_INI
sed -i 's/;opcache.validate_timestamps=.*/opcache.validate_timestamps=0/' $PHP_INI # Máximo rendimiento en prod

# --- INSTALACIÓN DE HERRAMIENTAS ---
echo -e "${BLUE}>>> 5. Instalando Composer y Nginx-UI...${NC}"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
bash -c "$(curl -L https://cloud.nginxui.com/install.sh)" @ install

# Reinicio de servicios para aplicar cambios
systemctl restart nginx
systemctl restart php$PHP_VAL-fpm

echo -e "${GREEN}>>> SERVIDOR OPTIMIZADO PARA ALTA CARGA COMPLETADO.${NC}"