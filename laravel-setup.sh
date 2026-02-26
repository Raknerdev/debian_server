#!/bin/bash

echo "🚀 Iniciando configuración avanzada: Redis (phpredis) + PgBouncer..."

# 1. Solicitar la ruta del proyecto
echo "📂 Ingresa la ruta del proyecto Laravel:"
read -r PROJECT_PATH

# Validaciones de existencia
if [ ! -d "$PROJECT_PATH" ] || [ ! -f "$PROJECT_PATH/config/database.php" ]; then
    echo "❌ Error: La ruta no es válida o no es un proyecto Laravel (falta config/database.php)"
    exit 1
fi

cd "$PROJECT_PATH" || exit

# --- FUNCIÓN DE UTILIDAD ---
update_env() {
    local key=$1
    local value=$2
    if grep -q "^$key=" .env; then
        sed -i "s|^$key=.*|$key=$value|" .env
    else
        echo "$key=$value" >> .env
    fi
}

# 2. Configuración del archivo .env
echo "📝 Actualizando archivo .env..."
update_env "CACHE_DRIVER" "redis"
update_env "CACHE_STORE" "redis"
update_env "SESSION_DRIVER" "redis"
update_env "QUEUE_CONNECTION" "redis"
update_env "REDIS_CLIENT" "phpredis"
update_env "DB_PORT" "6432"
update_env "DB_PREPARED_STATEMENTS" "false"
update_env "APP_TIMEZONE" "America/Caracas"

# 3. Modificación de archivos de configuración
echo "🛠️  Editando archivos de configuración..."

# A. Asegurar timezone en config/app.php
if [ -f "config/app.php" ]; then
    sed -i "s/'timezone' => '.*'/'timezone' => 'America\/Caracas'/g" config/app.php
    sed -i "s/'timezone' => env('APP_TIMEZONE', '.*')/'timezone' => env('APP_TIMEZONE', 'America\/Caracas')/g" config/app.php
fi

# B. Asegurar que Redis use el cliente del .env
sed -i "s/'client' => env('REDIS_CLIENT', '.*')/'client' => env('REDIS_CLIENT', 'phpredis')/g" config/database.php

# C. Configurar PgBouncer y timezone en pgsql
if grep -q "'driver' => 'pgsql'" config/database.php; then
    
    # 1. Eliminar bloque 'options' previo si existe para evitar duplicados (limpieza preventiva)
    # Buscamos el bloque options dentro del contexto de pgsql y lo borramos
    sed -i "/'driver' => 'pgsql'/,/],/ { /'options' => \[/,/\],/d }" config/database.php

    # 2. Gestionar la línea 'prepare'
    if grep -q "'prepare' =>" config/database.php; then
        sed -i "/'driver' => 'pgsql'/,/],/ s/'prepare' => .*,/'prepare' => env('DB_PREPARED_STATEMENTS', false),/" config/database.php
    else
        sed -i "/'driver' => 'pgsql',/a \            'prepare' => env('DB_PREPARED_STATEMENTS', false)," config/database.php
    fi

    # 3. Inyectar el bloque 'options' con PDO::ATTR_EMULATE_PREPARES
    # Se inserta justo debajo de la línea de 'prepare' recién creada o actualizada
    sed -i "/'prepare' => env('DB_PREPARED_STATEMENTS', false),/a \            'options' => [\n                PDO::ATTR_EMULATE_PREPARES => true,\n                PDO::ATTR_STRINGIFY_FETCHES => false,\n            ]," config/database.php

    # 4. Configurar timezone en pgsql
    if grep -q "'timezone' =>" config/database.php; then
        sed -i "/'driver' => 'pgsql'/,/],/ s/'timezone' => .*/'timezone' => 'America\/Caracas',/" config/database.php
    else
        sed -i "/'driver' => 'pgsql',/a \            'timezone' => 'America\/Caracas'," config/database.php
    fi

    echo "✅ Configuración de PgBouncer, PDO Options y timezone (America/Caracas) inyectada en pgsql."
fi

# 4. Instalación de dependencias y compilación
echo "📦 Ejecutando composer install..."
composer install --no-interaction --prefer-dist --optimize-autoloader

echo "🔑 Generando clave de la aplicación..."
php artisan key:generate

echo "� Creando enlace simbólico de almacenamiento..."
php artisan storage:link

echo "�📦 Instalando dependencias de Node (npm install)..."
npm install

echo "🔍 Verificando vulnerabilidades de npm..."
# npm audit devuelve un código de salida distinto de 0 si hay vulnerabilidades
if ! npm audit > /dev/null 2>&1; then
    echo "⚠️ Se encontraron vulnerabilidades. Ejecutando npm audit fix..."
    if ! npm audit fix; then
        echo "⚠️ Falló npm audit fix. Ejecutando npm audit fix --force..."
        npm audit fix --force
    fi
else
    echo "✅ No se encontraron vulnerabilidades."
fi

echo "🏗️  Compilando assets (npm run build)..."
npm run build

# 5. Configuración de permisos
echo "🔐 Configurando permisos..."
chown -R www-data:www-data "$PROJECT_PATH/public/index.php"
chown -R www-data:www-data "$PROJECT_PATH/storage/"
chown -R www-data:www-data "$PROJECT_PATH/bootstrap/cache/"

# 6. Finalización
echo "🧹 Limpiando caché..."
php artisan optimize:clear

echo "---"
echo "✨ ¡Proceso completado con éxito!"
echo "📍 Proyecto: $PROJECT_PATH"
echo "🔗 Redis: phpredis habilitado."
echo "🐘 PgBouncer: Puerto 6432, Prepared Statements desactivados y Emulación PDO activada."
echo "🇻🇪 Timezone: America/Caracas configurado."
echo "🔐 Permisos: www-data asignado a index.php, storage y cache."