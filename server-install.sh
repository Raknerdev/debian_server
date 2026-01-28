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
    php-fpm php-cli php-mbstring php-xml php-intl php-gd php-bcmath php-curl php-zip php-pgsql php-redis

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

# --- 3. Instalación Nginx-UI ---
bash -c "$(curl -L https://cloud.nginxui.com/install.sh)" @ install

echo -e "${GREEN}>>> INSTALACIÓN DE PAQUETES COMPLETADA.${NC}"