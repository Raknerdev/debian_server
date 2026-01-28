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
apt update && apt install -y htop nload iotop btop logtail --no-install-recommends

echo -e "${CYAN}>>> 2. Configurando Zswap...${NC}"

# Verificar si es un contenedor (LXC/Docker)
IS_CONTAINER=$(systemd-detect-virt --container)

if [ "$?" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Entorno de contenedor detectado ($IS_CONTAINER).${NC}"
    echo -e "${YELLOW}Zswap no puede activarse desde dentro de un contenedor.${NC}"
    echo -e "Debe activarse en el HOST físico ejecutando: "
    echo -e "echo 'zswap.enabled=1' >> /etc/default/grub (en el servidor principal)"
else
    echo -e "${CYAN}Activando Zswap en hardware real...${NC}"
    
    # Intentar activación en caliente
    echo 1 > /sys/module/zswap/parameters/enabled 2>/dev/null || echo -e "${RED}Fallo al activar en caliente.${NC}"
    echo lzo > /sys/module/zswap/parameters/compressor 2>/dev/null
    echo zsmalloc > /sys/module/zswap/parameters/zpool 2>/dev/null

    # Configuración permanente (Solo si existe GRUB)
    if [ -f /etc/default/grub ]; then
        if ! grep -q "zswap.enabled=1" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="zswap.enabled=1 zswap.compressor=lzo zswap.zpool=zsmalloc /' /etc/default/grub
            update-grub
            echo -e "${GREEN}Zswap configurado permanentemente en GRUB.${NC}"
        fi
    else
        echo -e "${YELLOW}No se detectó GRUB. Si usas systemd-boot, añade los parámetros manualmente a la línea de arranque.${NC}"
    fi
fi

echo -e "${CYAN}>>> 3. Resumen de herramientas:${NC}"
echo -e "${CYAN}htop${NC}   - CPU y procesos."
echo -e "${CYAN}nload${NC}  - Tráfico de red (2k usuarios)."
echo -e "${CYAN}btop${NC}   - Dashboard general."
echo -e "${CYAN}iotop${NC}  - Latencia de disco (Postgres/Redis)."

echo -e "${CYAN}>>> Proceso finalizado.${NC}"