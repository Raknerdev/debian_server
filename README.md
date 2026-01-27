# 🚀 Debian 13 Laravel High-Performance Stack

Este repositorio contiene un ecosistema de automatización diseñado para desplegar aplicaciones **Laravel** bajo condiciones de carga extrema en **Debian 13 (Trixie)**. El sistema está optimizado para manejar una concurrencia de hasta **2,000 usuarios constantes**.

## 🛠 Requisitos de Hardware
- **Mínimo:** 8GB RAM.
- **Recomendado:** 16GB+ RAM (Para manejar los 250 procesos PHP estáticos con fluidez).
- **SO:** Debian 13 (Instalación limpia).

---

## 📂 Descripción de los Scripts

### 1. `install.sh` (Despliegue y Tuning)
Este es el motor principal. Transforma una instalación limpia en un servidor de alto rendimiento eliminando cuellos de botella.

* **Stack Web:** Instala Nginx y PHP-FPM (excluyendo Apache2 para ahorrar recursos).
* **Base de Datos & Cache:** Configura extensiones para PostgreSQL y el servidor **Redis** con supervisión de `systemd`.
* **Tuning de Red:** Eleva `worker_connections` en Nginx a 10,240.
* **PHP-FPM Static:** Configura un pool fijo de **250 procesos hijos**. Esto elimina la latencia de creación/destrucción de procesos bajo carga masiva.
* **Kernel:** Ajusta el límite de archivos abiertos (`ulimit`) a 65,535.
* **Gestión:** Instala Composer y **Nginx-UI** (Panel visual).

### 2. `monitor.sh` (Observabilidad y Resiliencia)
Prepara el servidor para el mantenimiento y la estabilidad a largo plazo.

* **Zswap:** Activa la compresión de memoria RAM. Esto sirve para que, en caso de saturación, el sistema comprima datos en RAM en lugar de escribir en el disco lento (Swap física), manteniendo la velocidad de respuesta.
* **Tooling Pro:** Instala `btop`, `nload`, `htop` e `iotop` para monitorear CPU, Tráfico de Red y escritura en disco en tiempo real.

---

## 🚀 Instalación Rápida

Ejecuta estos comandos directamente desde tu terminal:

# 1. Instalar y Optimizar el Stack Base
```bash
curl -sSL https://raw.githubusercontent.com/Raknerdev/debian_server/main/install.sh | sudo bash

```

# 2. Configurar Monitoreo y Optimización de Memoria (Zswap)
```bash
curl -sSL https://raw.githubusercontent.com/Raknerdev/debian_server/main/monitor.sh | sudo bash

```
---

## 🛡️ Seguridad y Firewall (UFW)

Es fundamental abrir los puertos necesarios para que Laravel y el panel de administración funcionen correctamente. Aplica estas reglas para configurar tu firewall:

```bash
sudo ufw allow 80/tcp     # Tráfico Web HTTP
sudo ufw allow 443/tcp    # Tráfico Web HTTPS (SSL)
sudo ufw allow 7800/tcp   # Acceso al panel Nginx-UI
```

# Opcional: Asegúrate de tener acceso SSH antes de activar
```bash
sudo ufw allow 22/tcp
sudo ufw enable
```