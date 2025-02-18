#!/bin/bash
# Per vedere una copia di questa licenza, visita http://creativecommons.org/licenses/by-nc-sa/4.0/

BPPLCLIENTS="/usr/openv/netbackup/bin/admincmd/bpplclients"
BPTESTBPCD="/usr/openv/netbackup/bin/admincmd/bptestbpcd"

LOG_FILE="check_result.csv"

echo "hostname, ping, bptestbpcd" >> ${LOG_FILE}

echo "SUCCESS BPTEST ${client}"
echo "FAILED  BPTEST ${client}"
echo "FAILED  PING   ${client}"

total_client=0
total_success=0
total_failed=0

echo "NetBackup client test versione lite"
for client in $( ${BPPLCLIENTS} -allunique -noheader | cut -d' ' -f3 ); do
	((total_client++))
	ping -c 1 -W 2 ${client} &>/dev/null
	# Verifica ping
	if [ $? -ne 0 ]; then
		echo "${client}, FAILED, FAILED" >> ${LOG_FILE}
		echo "FAILED  PING   ${client}"
		((total_failed++))
	else
		# Se il ping va a buon fine effettuiamo il bptest
		${BPTESTBPCD} -client ${client} &>/dev/null
		if [ $? -eq 0 ]; then
			((total_success++))
			echo "${client}, SUCCESS, SUCCESS" >> ${LOG_FILE}
			echo "SUCCESS BPTEST ${client}"
		else
			((total_failed++))
			echo "${client}, SUCCESS, FAILED" >> ${LOG_FILE}
			echo "FAILED  BPTEST ${client}"
		fi
	fi
done

echo "Totale client      : ${total_client}"
echo "Client connessi    : ${total_success}"
echo "Client non connessi: ${total_failed}"
