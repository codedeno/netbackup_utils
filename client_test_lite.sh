#!/bin/bash
# Nome: Denis Gerolini
# Email: denis.gerolini@datacare.it
# Licenza: Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)
# Per vedere una copia di questa licenza, visita http://creativecommons.org/licenses/by-nc-sa/4.0/

BPPLCLIENTS="/usr/openv/netbackup/bin/admincmd/bpplclients"
BPTESTBPCD="/usr/openv/netbackup/bin/admincmd/bptestbpcd"
NBGETCONFIG="/usr/openv/netbackup/bin/nbgetconfig"

LOG_FILE="check_result.csv"

echo "hostname, ping, IP, bptestbpcd, client_name, version" > ${LOG_FILE}

total_client=0
total_success=0
total_failed=0

echo "NetBackup client test versione lite"
for client in $( ${BPPLCLIENTS} -allunique -noheader | cut -d' ' -f3 | sort | uniq ); do
        ((total_client++))
        ping -c 1 -W 2 ${client} &>/dev/null
        ping_res=$?
	# Verifico anche l'indirizzo IP
        ip=$( nslookup ${client} | awk '/^Address: / {print $2}' | tail -n1 )
        [[ ! -n "${ip}" ]] && ip="FAILED"
        # Verifica ping
        if [ ${ping_res} -ne 0 ]; then
                echo "${client}, FAILED, ${ip}, FAILED, FAILED, FAILED" >> ${LOG_FILE}
                echo "FAILED  PING   ${client}"
                ((total_failed++))
        else
                # Se il ping va a buon fine effettuiamo il bptest
                ${BPTESTBPCD} -client ${client} &>/dev/null
                if [ $? -eq 0 ]; then
                        ((total_success++))
			# Verifico CLIENT_NAME e Versione NetBackup installata
                        client_name=$( ${NBGETCONFIG} -M ${client} | grep ^CLIENT_NAME | cut -d'=' -f2 | tr -d ' ' )
                        version=$( ${NBGETCONFIG} -M ${client} | grep ^VERSIONINFO | cut -d' ' -f7 | tr -d '"' )
                        echo "${client}, SUCCESS, ${ip}, SUCCESS, ${client_name}, ${version}" >> ${LOG_FILE}
                        echo "SUCCESS BPTEST ${client}"

                else
                        ((total_failed++))
                        echo "${client}, SUCCESS, ${ip}, FAILED, FAILED, FAILED" >> ${LOG_FILE}
                        echo "FAILED  BPTEST ${client}"
                fi
        fi
done

echo "Totale client      : ${total_client}"
echo "Client connessi    : ${total_success}"
echo "Client non connessi: ${total_failed}"
