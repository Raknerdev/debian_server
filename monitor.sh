#!/bin/bash

# Colores
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Ejecuta como root.${NC}"
  exit 1
fi

echo -e "${CYAN}>>> 1. Instalando herramientas de monitoreo...${NC}"
# Instalamos solo lo esencial, omitiendo errores de paquetes no encontrados
apt update && apt install -y htop nload iotop btop logtail --no-install-recommends

echo -e "${CYAN}>>> 2. Intentando configurar Zswap...${NC}"

# Función para intentar escribir en /sys de forma segura
safe_write() {
    if [ -w "$1" ]; then
        echo "$2" > "$1" 2>/dev/null && echo -e "✅ $1 configurado."
    else
        return 1
    fi
}

# Intentar activar Zswap (fallará silenciosamente si es un contenedor)
if ! safe_write "/sys/module/zswap/parameters/enabled" "1"; then
    echo -e "${YELLOW}⚠️  No se puede modificar /sys (Entorno restringido/LXC).${NC}"
    echo -e "${YELLOW}   Zswap debe activarse desde el HOST físico.${NC}"
else
    safe_write "/sys/module/zswap/parameters/compressor" "lzo"
    safe_write "/sys/module/zswap/parameters/zpool" "zsmalloc"
fi

# Intentar configurar GRUB solo si el archivo existe
if [ -f /etc/default/grub ] && command -v update-grub >/dev/null 2>&1; then
    echo -e "${CYAN}Aplicando configuración permanente en GRUB...${NC}"
    if ! grep -q "zswap.enabled=1" /etc/default/grub; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="zswap.enabled=1 zswap.compressor=lzo zswap.zpool=zsmalloc /' /etc/default/grub
        update-grub
    fi
else
    echo -e "${YELLOW}ℹ️  GRUB no detectado o inaccesible. Omitiendo configuración de arranque.${NC}"
fi

echo -e "${CYAN}>>> 3. Resumen de herramientas instaladas:${NC}"
echo -e "   - ${CYAN}htop / btop:${NC} Monitoreo de CPU y procesos."
echo -e "   - ${CYAN}nload:${NC} Tráfico de red en tiempo real."
echo -e "   - ${CYAN}iotop:${NC} Actividad de lectura/escritura en disco."

echo -e "${CYAN}>>> Configuración finalizada.${NC}"