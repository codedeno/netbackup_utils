#!/usr/bin/env bash
#Lo script aggiunge in modo sicuro un Media Server nel bp.conf di un client. Mantiene inoltre l'ordine originale
#Limitato a un solo client, quindi potrebbe non essere completamente utilissimo

#       Esecuzione dello script come root
if [ "$(id -u)" -ne 0 ]; then
        echo "Lo script deve essere eseguito come root"
        exit 1
fi

#       Richiede client e media server
read -p "Inserisci il nome del client su cui aggiungere il Media Server: " client
read -p "Inserisci il nome del Media Server da aggiungere al client: " new_media_server


#       Crea un file temporaneo sicuro
tmp_file=$(mktemp)

if [ ! -f "${tmp_file}" ]; then
        echo "Errore durante la creazione del file temporaneo per il backup delle entry SERVER, esco"
        exit 1
fi

#       Eseguibili veritas
NBGETCONFIG="/usr/openv/netbackup/bin/nbgetconfig"
NBSETCONFIG="/usr/openv/netbackup/bin/nbsetconfig"

#       Verifica i Server attualmente presenti nel bp.conf
${NBGETCONFIG} -M ${client} | grep -iE '^SERVER | ^SERVER=' > "${tmp_file}" 2>/dev/null
if [ $? -ne 0 ]; then
        echo "Errore nel recupero delle informazioni dal host ${client}, esco!"
        rm -f "${tmp_file}"
        exit 1
fi

#       Se il server da aggiungere non è già presente lo aggiungo
if ! grep -qi ${new_media_server} ${tmp_file}; then
        echo "SERVER = ${new_media_server}" >> "${tmp_file}"
else
        echo "Il server ${new_media_server} è già presente nel bp.conf, esco!"
        rm -f "${tmp_file}"
        exit 1
fi

#       Aggiungo i server nel bp.conf
${NBSETCONFIG} -h "${client}" "${tmp_file}" >/dev/null
if [ $? -ne 0 ]; then
        echo "Errore durante l'aggiornamento del host ${client}, esco!"
        rm -f "${tmp_file}"
        exit 1
fi

rm -f "${tmp_file}"
