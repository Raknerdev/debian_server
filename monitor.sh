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

echo -e "${CYAN}>>> 1. Verificando herramientas de monitoreo...${NC}"
apt update && apt install -y htop nload iotop btop logtail --no-install-recommends

echo -e "${CYAN}>>> 2. Configuración de Memoria y Zswap...${NC}"

# Función para intentar escribir solo si el archivo es escribible
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

# Gestionar GRUB (Solo si existe el archivo y el comando)
if [ -f /etc/default/grub ] && command -v update-grub >/dev/null 2>&1; then
    echo -e "${CYAN}Actualizando GRUB...${NC}"
    if ! grep -q "zswap.enabled=1" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="zswap.enabled=1 zswap.compressor=lzo zswap.zpool=zsmalloc /' /etc/default/grub
        update-grub
    fi
else
    echo -e "${YELLOW}ℹ️  Configuración de arranque omitida (No se detectó GRUB/Host LXC).${NC}"
fi

echo -e "${CYAN}>>> 3. Diagnóstico de Optimización de Memoria:${NC}"

# Verificar si Zswap está activo en el Kernel
ZSWAP_STATE=$(cat /sys/module/zswap/parameters/enabled 2>/dev/null)

if [ "$ZSWAP_STATE" == "Y" ] || [ "$ZSWAP_STATE" == "1" ]; then
    echo -e "Zswap Status: ${GREEN}ACTIVO (Memoria Comprimida Habilitada)${NC}"
    COMPRESSOR=$(cat /sys/module/zswap/parameters/compressor 2>/dev/null)
    echo -e "Algoritmo: ${GREEN}$COMPRESSOR${NC}"
else
    echo -e "Zswap Status: ${RED}INACTIVO${NC}"
    echo -e "${YELLOW}Nota: Si estás en LXC, actívalo en el Host de Proxmox siguiendo la guía del README.${NC}"
fi

# Verificar SWAP física (Zswap la necesita para funcionar)
SWAP_TOTAL=$(free -m | grep Swap | awk '{print $2}')
if [ "$SWAP_TOTAL" -eq 0 ]; then
    echo -e "Swap Física: ${RED}NO DETECTADA${NC}"
    echo -e "${YELLOW}Creando archivo swap de emergencia (2GB)...${NC}"
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo -e "${GREEN}✅ Swap de 2GB creada y activada.${NC}"
else
    echo -e "Swap Física: ${GREEN}${SWAP_TOTAL}MB disponibles.${NC}"
fi



echo -e "${CYAN}>>> 4. Resumen de herramientas:${NC}"
echo -e "   - ${CYAN}htop / btop:${NC} Monitoreo de procesos y carga."
echo -e "   - ${CYAN}nload:${NC} Tráfico de red (ideal para tus 2k usuarios)."
echo -e "   - ${CYAN}iotop:${NC} Diagnóstico de saturación de disco."

echo -e "${GREEN}>>> Proceso finalizado con éxito.${NC}"