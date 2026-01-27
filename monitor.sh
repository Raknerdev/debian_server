#!/bin/bash

# Colores
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
  echo "Ejecuta como root."
  exit 1
fi

echo -e "${CYAN}>>> 1. Instalando herramientas de monitoreo...${NC}"
# htop: Procesos y RAM | nload: Tráfico de red | iotop: Uso de Disco | glitcher: Logs
apt update && apt install -y htop nload iotop btop logtail

echo -e "${CYAN}>>> 2. Activando y configurando Zswap...${NC}"
# Activar zswap
echo 1 > /sys/module/zswap/parameters/enabled
# Usar el compresor lzo (rápido) y el pool zsmalloc (eficiente)
echo lzo > /sys/module/zswap/parameters/compressor
echo zsmalloc > /sys/module/zswap/parameters/zpool

# Hacer que Zswap sea permanente tras reinicios
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="zswap.enabled=1 zswap.compressor=lzo zswap.zpool=zsmalloc /' /etc/default/grub
update-grub

echo -e "${CYAN}>>> 3. Resumen de herramientas instaladas:${NC}"
echo -e "${CYAN}htop${NC}   - Ver consumo de CPU y procesos PHP."
echo -e "${CYAN}nload${NC}  - Ver ancho de banda ocupado por los 2000 usuarios."
echo -e "${CYAN}btop${NC}   - Interfaz moderna para estadísticas generales."
echo -e "${CYAN}iotop${NC}  - Ver si Redis o Postgres están saturando el disco."

echo -e "${CYAN}>>> Configuración de monitoreo y Zswap completada.${NC}"