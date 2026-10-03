#!/bin/bash


INSTALL_DIR="/usr/local/bin"

if [ ! -f "$INSTALL_DIR/ani-es" ]; then
    echo "El script ani-es no está instalado en el sistema."
    exit 1
fi

sudo rm -f "$INSTALL_DIR/ani-es"
# restos de versiones viejas (ya no se usan)
sudo rm -f "$INSTALL_DIR/excepciones.json"

read -r -p "¿Borrar también el historial (~/ani-es/history.json)? [s/N] " resp
if [[ "$resp" =~ ^[sS]$ ]]; then
    rm -f ~/ani-es/history.json ~/ani-es/history.json.bak
    echo "Historial eliminado."
else
    echo "Historial conservado en ~/ani-es/history.json."
fi

echo "El script ani-es ha sido desinstalado correctamente."
