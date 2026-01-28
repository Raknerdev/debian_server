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

# 3. Modificación de config/database.php
echo "🛠️  Editando config/database.php..."

# A. Asegurar que Redis use el cliente del .env
sed -i "s/'client' => env('REDIS_CLIENT', '.*')/'client' => env('REDIS_CLIENT', 'phpredis')/g" config/database.php

# B. Configurar PgBouncer (Prepared Statements + PDO Options) en pgsql
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

    echo "✅ Configuración de PgBouncer y PDO Options inyectada en pgsql."
fi

# 4. Finalización
echo "🧹 Limpiando caché..."
php artisan config:clear

echo "---"
echo "✨ ¡Proceso completado con éxito!"
echo "📍 Proyecto: $PROJECT_PATH"
echo "🔗 Redis: phpredis habilitado."
echo "🐘 PgBouncer: Puerto 6432, Prepared Statements desactivados y Emulación PDO activada."