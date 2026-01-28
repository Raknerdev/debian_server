# 🚀 Debian 13 Laravel High-Performance Stack

Este repositorio contiene un ecosistema de automatización diseñado para desplegar aplicaciones **Laravel** bajo condiciones de carga extrema en **Debian 13 (Trixie)**. El sistema está optimizado para manejar una concurrencia de hasta **2,000 usuarios constantes**.

## 🛠 Requisitos de Hardware
- **Mínimo:** 8GB RAM.
- **Recomendado:** 16GB+ RAM (Para manejar los 250 procesos PHP estáticos con fluidez).
- **SO:** Debian 13 (Instalación limpia).

---

## 📂 Descripción de los Scripts

### 1. `install.sh` (Despliegue y Tuning)
Este es el motor principal. Transforma una instalación limpia en un servidor de alto rendimiento eliminando cuellos de botella mediante las siguientes acciones:

* **Repositorios Oficiales:** Configura las fuentes oficiales de **Redis** y **Node.js (LTS)** para asegurar versiones actualizadas y parches de seguridad recientes.
* **Stack Web:** Instala Nginx y PHP-FPM, forzando la exclusión de Apache2 para optimizar el consumo de recursos.
* **Gestión de Dependencias:** Instalación segura de **Composer** mediante verificación dinámica de firma (checksum) para prevenir instaladores corruptos o malintencionados.
* **Compilación de Assets:** Incluye **Node.js y NPM** para dar soporte nativo a Vite y otras herramientas de frontend modernas.
* **Base de Datos & Cache:** Configura extensiones para PostgreSQL y el servidor **Redis**, este último optimizado con una política de memoria `allkeys-lru` y supervisión de `systemd`.
* **Tuning de Red y Kernel:**
    * Eleva `worker_connections` en Nginx a 10,240.
    * Optimiza el stack TCP/IP (vía `sysctl`) permitiendo la reutilización de sockets (`tcp_tw_reuse`) y ampliando la cola de conexiones pendientes (`somaxconn`).
* **Rendimiento PHP (Static Pool & OPcache):**
    * Configura un pool fijo de **250 procesos hijos**, eliminando la latencia de creación/destrucción de procesos.
    * Optimiza **OPcache** con 256MB de memoria y `validate_timestamps=0` para servir el código directamente desde la RAM sin consultar el disco.
* **Límites del Sistema:** Ajusta el límite de archivos abiertos (`ulimit`) a 65,535, permitiendo que el sistema operativo soporte el alto volumen de descriptores de archivos concurrentes.
* **Interfaz de Gestión:** Instala **Nginx-UI** para la administración visual de servidores, certificados SSL y logs.

### 2. `monitor.sh` (Observabilidad y Resiliencia)
Prepara el servidor para el mantenimiento y la estabilidad a largo plazo.

* **Zswap:** Activa la compresión de memoria RAM. Esto sirve para que, en caso de saturación, el sistema comprima datos en RAM en lugar de escribir en el disco lento (Swap física), manteniendo la velocidad de respuesta.
* **Tooling Pro:** Instala `btop`, `nload`, `htop` e `iotop` para monitorear CPU, Tráfico de Red y escritura en disco en tiempo real.

### 3. `laravel-setup.sh` (Optimización de Aplicación)
Este script cierra la brecha entre la infraestructura y el código, configurando el proyecto Laravel para aprovechar al máximo **Redis** y **PgBouncer** (Pool de conexiones).

* **Configuración Redis (phpredis):**
    * Fuerza el uso del cliente `phpredis` (extensión nativa de C) en lugar de la librería de Composer, reduciendo drásticamente el uso de CPU y la latencia.
    * Migra automáticamente los drivers de `CACHE`, `SESSION` y `QUEUE` hacia Redis para minimizar tiempos de respuesta.
* **Integración con PgBouncer (Transaction Mode):**
    * Reconfigura el puerto de base de datos al `6432` y ajusta las variables de entorno para operar en modo pool de transacciones.
    * **Seguridad en el Pool:** Desactiva `DB_PREPARED_STATEMENTS` para evitar colisiones de memoria en el servidor de base de datos cuando múltiples procesos comparten la misma conexión física.
* **Tuning de PDO (Emulated Prepares):**
    * Inyecta quirúrgicamente en `config/database.php` el bloque de opciones `PDO::ATTR_EMULATE_PREPARES => true`.
    * Esto permite que PHP ensamble las consultas localmente antes de enviarlas, eliminando los errores de protocolo `"prepared statement already exists"` comunes en entornos con balanceo de conexiones.
* **Higiene de Configuración:** Finaliza con una limpieza automática de caché interna (`config:clear`) para asegurar la persistencia de los cambios.

---

## 🚀 Flujo de Ejecución Recomendado

Para un despliegue óptimo, sigue este orden:

1.  **Configurar el Servidor:** Ejecuta `./install.sh` en tu nueva instancia.
2.  **Optimizar el Sistema:** Ejecuta `./monitor.sh` para activar Zswap y herramientas de monitoreo.
3.  **Configurar la App:** Una vez clonado tu proyecto Laravel, ejecuta `./laravel-setup.sh` e ingresa la ruta del proyecto.

---

## 🚀 Instalación Rápida

Ejecuta estos comandos directamente desde tu terminal:

* **Instalar y Optimizar el Stack Base**
```bash
curl -sSL https://raw.githubusercontent.com/Raknerdev/debian_server/main/install.sh | sudo bash

```

* **Configurar Monitoreo y Optimización de Memoria (Zswap)**
```bash
curl -sSL https://raw.githubusercontent.com/Raknerdev/debian_server/main/monitor.sh | sudo bash
```

* **Optimización de Aplicación Laravel**
```bash
curl -sSL https://raw.githubusercontent.com/Raknerdev/debian_server/main/laravel-setup.sh | sudo bash
```
---

## 🛡️ Seguridad y Firewall (UFW)

Es fundamental abrir los puertos necesarios para que Laravel y el panel de administración funcionen correctamente. Aplica estas reglas para configurar tu firewall:

```bash
sudo ufw allow 80/tcp     # Tráfico Web HTTP
sudo ufw allow 443/tcp    # Tráfico Web HTTPS (SSL)
sudo ufw allow 7800/tcp   # Acceso al panel Nginx-UI
```

* **Opcional: Asegúrate de tener acceso SSH antes de activar**
```bash
sudo ufw allow 22/tcp
sudo ufw enable
```