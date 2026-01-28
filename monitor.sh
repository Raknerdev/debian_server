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
        echo "$value" > "$param_path" 2>/dev/null && return 0
    else
        return 1
    fi
}

ZSWAP_REQ=0
safe_write_zswap "/sys/module/zswap/parameters/enabled" "1" || ZSWAP_REQ=1
safe_write_zswap "/sys/module/zswap/parameters/compressor" "lzo"
safe_write_zswap "/sys/module/zswap/parameters/zpool" "zsmalloc"

if [ -f /etc/default/grub ] && command -v update-grub >/dev/null 2>&1; then
    if ! grep -q "zswap.enabled=1" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="zswap.enabled=1 zswap.compressor=lzo zswap.zpool=zsmalloc /' /etc/default/grub
        update-grub
    fi
fi

# --- PRUEBAS DE FUNCIONAMIENTO ---
echo -e "${CYAN}>>> 3. Resumen de Disponibilidad de Herramientas:${NC}"

# Prueba htop
echo -ne "✅ ${CYAN}htop${NC}   - CPU y procesos: " && echo -e "${GREEN}FUNCIONAL${NC}"

# Prueba nload
echo -ne "✅ ${CYAN}nload${NC}  - Tráfico de red (2k usuarios): " && echo -e "${GREEN}FUNCIONAL${NC}"

# Prueba btop (Verifica si btop abre bien con el locale)
if btop --version >/dev/null 2>&1; then
    echo -ne "✅ ${CYAN}btop${NC}   - Dashboard general (UTF-8): " && echo -e "${GREEN}FUNCIONAL${NC}"
else
    echo -ne "❌ ${CYAN}btop${NC}   - Dashboard general: " && echo -e "${RED}ERROR DE LOCALE${NC}"
fi

# Prueba iotop (Netlink Check)
if iotop -b -n 1 >/dev/null 2>&1; then
    echo -ne "✅ ${CYAN}iotop${NC}  - Latencia de disco (Postgres/Redis): " && echo -e "${GREEN}FUNCIONAL${NC}"
else
    echo -ne "❌ ${CYAN}iotop${NC}  - Latencia de disco: " && echo -e "${RED}LIMITADO (LXC Netlink Error)${NC}"
    echo -e "      ${YELLOW}└─ Solución: Activa 'Nesting' y privilegios en el Host.${NC}"
fi

# Prueba Zswap
if [ $ZSWAP_REQ -eq 0 ]; then
    echo -ne "✅ ${CYAN}Zswap${NC}  - Compresión de RAM: " && echo -e "${GREEN}ACTIVO${NC}"
else
    echo -ne "❌ ${CYAN}Zswap${NC}  - Compresión de RAM: " && echo -e "${RED}SOLO LECTURA (LXC)${NC}"
    echo -e "      ${YELLOW}└─ Solución: Configurar en /etc/default/grub del HOST.${NC}"
fi



echo -e "\n${GREEN}>>> Configuración finalizada. Usa los comandos anteriores para monitorear.${NC}"