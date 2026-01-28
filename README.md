# 🚀 Debian 13 Laravel High-Performance Stack

Este repositorio contiene un ecosistema de automatización diseñado para desplegar aplicaciones **Laravel** bajo condiciones de carga extrema en **Debian 13 (Trixie)**. El sistema está optimizado para manejar una concurrencia masiva de hasta **2,000 usuarios constantes**.

## 🛠 Requisitos de Hardware
- **Mínimo:** 8GB RAM.
- **Recomendado:** 16GB+ RAM (Para manejar los 250 procesos PHP estáticos con fluidez).
- **SO:** Debian 13 (Instalación limpia).

---

## 📂 Descripción de los Scripts

### 1. `server-install.sh` (Aprovisionamiento)
Este script prepara el terreno instalando los binarios necesarios desde fuentes oficiales:
* **Repositorios Oficiales:** Configura **Redis** y **Node.js (LTS)** para asegurar parches de seguridad recientes.
* **Stack Web:** Instalación limpia de Nginx, PHP-FPM y extensiones críticas (`php-redis`, `php-pgsql`, etc.).
* **Composer Seguro:** Instalación de Composer verificando el checksum dinámico para garantizar la integridad del binario.

### 2. `server-tune.sh` (Sintonización de Infraestructura)
Aplica la "sintonía fina" al sistema operativo y servicios para eliminar cuellos de botella:
* **Tuning de Procesos (Afinidad de Hardware):** Implementa `worker_cpu_affinity auto` en Nginx para vincular procesos a núcleos físicos, optimizando la caché L1/L2.
* **Optimización de Red y Kernel:** Ajusta el stack TCP/IP vía `sysctl` para permitir la reutilización de sockets y ampliar la cola de conexiones (`somaxconn`).
* **Rendimiento PHP (Static Pool):** Configura un pool de **250 procesos hijos fijos** y optimiza **OPcache** para servir código directamente desde RAM.
* **Tuning de Redis:** Configura políticas `allkeys-lru` y aumenta los límites de clientes y memoria.
* **Gestión Visual:** Instala **Nginx-UI** para administrar el servidor de forma gráfica.



### 3. `monitor.sh` (Observabilidad y Resiliencia)
* **Zswap:** Activa la compresión de memoria RAM para evitar latencia de escritura en disco (Swap física).
* **Tooling Pro:** Instala `btop`, `nload` y otros monitores de tráfico y CPU en tiempo real.

### 4. `laravel-setup.sh` (Optimización de Aplicación)
El puente final entre el código y el hardware:
* **phpredis Nativo:** Configura el cliente de C para Redis en lugar de la librería PHP, bajando la latencia.
* **Modo PgBouncer:** Ajusta el puerto a `6432` y desactiva `DB_PREPARED_STATEMENTS`.
* **PDO Emulated Prepares:** Inyecta `PDO::ATTR_EMULATE_PREPARES => true` para garantizar estabilidad total en pools de conexiones.

---

## 🚀 Flujo de Ejecución Recomendado

1.  **Instalar Paquetes:** `./server-install.sh`
2.  **Sintonizar Servidor:** `./server-tune.sh`
3.  **Activar Monitoreo:** `./monitor.sh`
4.  **Optimizar App Laravel:** `./laravel-setup.sh` (Ejecutar en la raíz del proyecto).

---

## 🚀 Instalación Rápida

Ejecuta estos comandos directamente desde tu terminal:

* **Instalar y Sintonizar el Stack Base (All in One)**
```bash
curl -sSL https://raw.githubusercontent.com/Raknerdev/debian_server/main/install.sh | sudo bash

```

* **Instalar el Stack Base**
```bash
curl -sSL https://raw.githubusercontent.com/Raknerdev/debian_server/main/server-install.sh | sudo bash

```

* **Sintonizar Hardware y Red**
```bash
curl -sSL https://raw.githubusercontent.com/Raknerdev/debian_server/main/server-tune.sh | sudo bash

```

* **Configurar Monitoreo y Zswap**
```bash
curl -sSL https://raw.githubusercontent.com/Raknerdev/debian_server/main/monitor.sh | sudo bash
```

* **Optimización de Proyecto Laravel**
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