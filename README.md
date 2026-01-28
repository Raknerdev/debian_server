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
* **Gestión Visual:** Instala **Nginx-UI** para administrar el servidor de forma gráfica.

### 2. `server-tune.sh` (Sintonización de Infraestructura)
Aplica la "sintonía fina" al sistema operativo y servicios para eliminar cuellos de botella:
* **Tuning de Procesos (Afinidad de Hardware):** Implementa `worker_cpu_affinity auto` en Nginx para vincular procesos a núcleos físicos, optimizando la caché L1/L2.
* **Optimización de Red y Kernel:** Ajusta el stack TCP/IP vía `sysctl` para permitir la reutilización de sockets y ampliar la cola de conexiones (`somaxconn`).
* **Rendimiento PHP (Static Pool):** Configura un pool de **250 procesos hijos fijos** y optimiza **OPcache** para servir código directamente desde RAM.
* **Tuning de Redis:** Configura políticas `allkeys-lru` y aumenta los límites de clientes y memoria.

### 3. `monitor.sh` (Observabilidad y Resiliencia)
* **Zswap:** Activa la compresión de memoria RAM para evitar latencia de escritura en disco (Swap física).
* **Tooling Pro:** Instala `btop`, `nload` y otros monitores de tráfico y CPU en tiempo real.

## 📊 Diagnóstico y Monitoreo de Rendimiento

El script `monitor.sh` incluye un módulo de diagnóstico que verifica la salud de la optimización de memoria y prepara el entorno para soportar hasta 2,000 usuarios concurrentes.

### 🔍 Interpretación de Resultados de Memoria
* **Zswap ACTIVO:** ✅ El servidor está comprimiendo las páginas de memoria inactivas en la RAM. Esto reduce el uso de I/O de disco y acelera Laravel significativamente en momentos de alta concurrencia.
* **Zswap INACTIVO:** ❌ El sistema está usando Swap tradicional (lenta) o corre el riesgo de activar el *OOM Killer* (cierre forzado de procesos). Si ves este mensaje, consulta la **Guía de Configuración en el Host**.
* **Swap Física:** Zswap actúa como un "filtro" antes de la Swap física. Se recomienda tener al menos **2GB de Swap** configurada (en contenedores LXC, esto se gestiona en los recursos del contenedor desde la interfaz de Proxmox).

---

### 🛠️ Herramientas de Monitoreo en Vivo

Tras ejecutar el script, dispondrás de las siguientes herramientas para gestionar el tráfico y la estabilidad:

1. **`btop`**: La interfaz más avanzada y estética. Visualiza el uso de CPU por núcleos, RAM comprimida (Zswap) y procesos en tiempo real con gráficos de alta resolución.
2. **`htop`**: El estándar de la industria. Ideal para inspeccionar la carga del sistema y gestionar procesos individuales (como liberar procesos bloqueados de PHP-FPM).
3. **`nload`**: Monitor de red en tiempo real. Fundamental para detectar si los picos de tráfico de tus 2,000 usuarios están saturando el ancho de banda.
4. **`iotop -o`**: Muestra solo procesos con actividad de disco activa. Esencial para identificar si Redis o PostgreSQL están causando cuellos de botella en las escrituras.
5. **`logtail`**: Monitor de logs ligero. Perfecto para seguir `storage/logs/laravel.log` o los accesos de Nginx en vivo sin consumir recursos excesivos de la terminal.

---

### 💡 Comandos Rápidos Recomendados

* **Ver tráfico de red:** `nload`
* **Ver quién escribe en disco:** `iotop -o`
* **Ver logs de Laravel en vivo:** `logtail -f /ruta/a/tu/laravel/storage/logs/laravel.log`
* **Panel de control total:** `btop`

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
sudo ufw allow 9000/tcp   # Acceso al panel Nginx-UI
```

* **Opcional: Asegúrate de tener acceso SSH antes de activar**
```bash
sudo ufw allow 22/tcp
sudo ufw enable
```


---

## 🛠 Solución para Entornos Virtualizados (Proxmox / LXC / Docker)

Si al ejecutar `./monitor.sh` obtienes marcas rojas (❌), errores de `Read-only file system` o `command not found`, es porque estás operando en un entorno de virtualización ligera. Los contenedores comparten el Kernel del host y, por seguridad, tienen restringido el acceso a funciones avanzadas.

### 1. Habilitar `iotop` (Netlink / NET_ADMIN)
Para que `iotop` pueda monitorizar la latencia de disco de procesos como PostgreSQL o Redis dentro de un LXC, debes relajar las restricciones de privilegios desde el servidor físico.

**En el Host de Proxmox:**
1. Apaga el contenedor:
    ```bash
    pct stop <ID_DEL_CT>
    ```
2. Edita el archivo de configuración:
    ```bash
    nano /etc/pve/lxc/<ID_DEL_CT>.conf
    ```
3. Añade la siguiente línea al final del archivo:
   ```bash
    lxc.cap.drop:
    ```
4. *(Opcional)* En la interfaz web, ve a **Options > Features** y marca **Nesting**.
5. Inicia el contenedor:
    ```bash
    pct start <ID_DEL_CT>
    ```

### 2. Habilitar `Zswap` (Configuración de Kernel)
Zswap debe activarse en el **HOST físico**. Una vez habilitado, el Kernel comprimirá automáticamente las páginas de memoria de todos los contenedores antes de tocar el disco.

**En el Host de Proxmox / Servidor Dedicado:**
1. Edita el archivo de arranque:
    ```bash
    sudo nano /etc/default/grub
    ```

2. Busca la línea:
    ```bash
    GRUB_CMDLINE_LINUX_DEFAULT
    ```
    Añade los parámetros:
    ```bash
    GRUB_CMDLINE_LINUX_DEFAULT="quiet zswap.enabled=1 zswap.compressor=lzo zswap.zpool=zsmalloc"
    ```

3. Actualiza el cargador y reinicia el servidor físico:
    ```bash
    sudo update-grub
    sudo reboot
    ```

### 🚀 Beneficios para el Stack de Alto Rendimiento
Al activar estas funciones en el Host, tu infraestructura Laravel obtiene mejoras críticas:

* **Visibilidad Total**: `iotop` permitirá detectar si los logs de Laravel o las persistencias de Redis están saturando el I/O del disco.
* **Menor Latencia**: Los datos se comprimen en RAM mediante Zswap, evitando la lentitud de la Swap física en picos de alta concurrencia.
* **Resiliencia**: Los 250 procesos de PHP-FPM coexisten de forma más eficiente sin riesgo de activar el *OOM Killer* del Kernel.

### Verificación Final
Vuelve a ejecutar el script dentro de tu contenedor para confirmar que todo esté en verde:
    
    curl -sSL https://raw.githubusercontent.com/Raknerdev/debian_server/main/monitor.sh | sudo bash
