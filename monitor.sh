#!/bin/bash

# Colores
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Ejecuta como root.${NC}"
  exit 1
fi

echo -e "${CYAN}>>> 0. Configurando Locales (UTF-8)...${NC}"
apt update && apt install -y locales --no-install-recommends
sed -i '/en_US.UTF-8 UTF-8/s/^# //g' /etc/locale.gen
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo -e "${CYAN}>>> 1. Verificando herramientas de monitoreo...${NC}"
apt install -y htop nload iotop btop logtail --no-install-recommends

echo -e "${CYAN}>>> 2. Configuración de Memoria y Zswap...${NC}"

safe_write_zswap() {
    local param_path=$1
    local value=$2
    if [ -w "$param_path" ]; then
        echo "$value" > "$param_path" 2>/dev/null && echo -e "✅ $param_path actualizado."
    else
        echo -e "${YELLOW}ℹ️  Omitiendo $param_path (LXC detectado)${NC}"
    fi
}

safe_write_zswap "/sys/module/zswap/parameters/enabled" "1"
safe_write_zswap "/sys/module/zswap/parameters/compressor" "lzo"
safe_write_zswap "/sys/module/zswap/parameters/zpool" "zsmalloc"

if [ -f /etc/default/grub ] && command -v update-grub >/dev/null 2>&1; then
    echo -e "${CYAN}Actualizando GRUB...${NC}"
    if ! grep -q "zswap.enabled=1" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="zswap.enabled=1 zswap.compressor=lzo zswap.zpool=zsmalloc /' /etc/default/grub
        update-grub
    fi
else
    echo -e "${YELLOW}ℹ️  Configuración de arranque omitida (Host LXC).${NC}"
fi

echo -e "${CYAN}>>> 3. Diagnóstico Final:${NC}"

# Verificar si iotop tiene permisos de Netlink
if ! iotop -b -n 1 >/dev/null 2>&1; then
    echo -e "I/O Monitoring: ${RED}ERROR (Netlink Permission Denied)${NC}"
    echo -e "${YELLOW}Para arreglarlo: En Proxmox Host, añade 'lxc.cap.drop:' al .conf del contenedor.${NC}"
else
    echo -e "I/O Monitoring: ${GREEN}OK${NC}"
fi

# Verificar Zswap
ZSWAP_STATE=$(cat /sys/module/zswap/parameters/enabled 2>/dev/null)
if [ "$ZSWAP_STATE" == "Y" ] || [ "$ZSWAP_STATE" == "1" ]; then
    echo -e "Zswap: ${GREEN}ACTIVO${NC}"
else
    echo -e "Zswap: ${RED}INACTIVO (LXC)${NC}"
fi

echo -e "${CYAN}>>> Configuración finalizada.${NC}"