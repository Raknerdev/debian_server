#!/bin/bash

# Colores
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Verificar privilegios de root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Error: Este script debe ejecutarse como root.${NC}"
  exit 1
fi

echo -e "${CYAN}>>> 0. Configurando Locales (UTF-8) para btop/iotop...${NC}"
# Instalar paquete de locales y generar el set de caracteres necesario
apt update && apt install -y locales --no-install-recommends
sed -i '/en_US.UTF-8 UTF-8/s/^# //g' /etc/locale.gen
locale-gen en_US.UTF-8

# Aplicar variables de entorno para la sesión actual
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# Hacerlo permanente para el sistema
if command -v update-locale >/dev/null 2>&1; then
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
fi

echo -e "${CYAN}>>> 1. Verificando herramientas de monitoreo...${NC}"
apt install -y htop nload iotop btop logtail --no-install-recommends

echo -e "${CYAN}>>> 2. Configuración de Memoria y Zswap...${NC}"

# Función para intentar escribir solo si el archivo es escribible (Evita error LXC)
safe_write_zswap() {
    local param_path=$1
    local value=$2
    if [ -w "$param_path" ]; then
        echo "$value" > "$param_path" 2>/dev/null && echo -e "✅ $param_path actualizado."
    else
        echo -e "${YELLOW}ℹ️  Omitiendo $param_path (Solo lectura en LXC/Proxmox)${NC}"
    fi
}

# Intentar configurar parámetros de Zswap
safe_write_zswap "/sys/module/zswap/parameters/enabled" "1"
safe_write_zswap "/sys/module/zswap/parameters/compressor" "lzo"
safe_write_zswap "/sys/module/zswap/parameters/zpool" "zsmalloc"

# Gestionar GRUB (Solo si existe el archivo y el comando - Hardware Real/KVM)
if [ -f /etc/default/grub ] && command -v update-grub >/dev/null 2>&1; then
    echo -e "${CYAN}Actualizando configuración permanente en GRUB...${NC}"
    if ! grep -q "zswap.enabled=1" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="zswap.enabled=1 zswap.compressor=lzo zswap.zpool=zsmalloc /' /etc/default/grub
        update-grub
    fi
else
    echo -e "${YELLOW}ℹ️  Configuración de arranque omitida (Host LXC detectado).${NC}"
fi

echo -e "${CYAN}>>> 3. Diagnóstico de Salud del Sistema:${NC}"

# --- Verificación Zswap ---
ZSWAP_STATE=$(cat /sys/module/zswap/parameters/enabled 2>/dev/null)
if [ "$ZSWAP_STATE" == "Y" ] || [ "$ZSWAP_STATE" == "1" ]; then
    echo -e "Zswap: ${GREEN}ACTIVO${NC}"
else
    echo -e "Zswap: ${RED}INACTIVO${NC} (Actívalo en el Host Proxmox si es LXC)"
fi

# --- Verificación SWAP física ---
SWAP_TOTAL=$(free -m | grep Swap | awk '{print $2}')
if [ "$SWAP_TOTAL" -eq 0 ]; then
    echo -e "Swap Física: ${RED}NO DETECTADA${NC}"
    echo -e "${YELLOW}Creando archivo swap de emergencia (2GB)...${NC}"
    fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile && swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo -e "${GREEN}✅ Swap de 2GB creada.${NC}"
else
    echo -e "Swap Física: ${GREEN}${SWAP_TOTAL}MB disponibles.${NC}"
fi

# --- Verificación Privilegios iotop (Netlink) ---
if ! iotop -b -n 1 >/dev/null 2>&1; then
    echo -e "I/O Monitoring: ${RED}SIN PERMISOS (Netlink Error)${NC}"
    echo -e "${YELLOW}Tip: En Proxmox, activa 'Nesting' y 'Sysadmin' en las Features del LXC.${NC}"
else
    echo -e "I/O Monitoring: ${GREEN}OK${NC}"
fi



echo -e "${CYAN}>>> 4. Resumen de comandos:${NC}"
echo -e "   - ${CYAN}btop${NC}   : Dashboard moderno (Requiere UTF-8, ya configurado)."
echo -e "   - ${CYAN}nload${NC}  : Monitor de red para tus 2000 usuarios."
echo -e "   - ${CYAN}iotop${NC}  : Monitor de disco (Requiere privilegios NET_ADMIN)."

echo -e "${GREEN}>>> Monitor Stack configurado correctamente.${NC}"