#!/bin/bash
# Nome: Denis Gerolini
# Email: denis.gerolini@datacare.it
# Licenza: Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)
# Per vedere una copia di questa licenza, visita http://creativecommons.org/licenses/by-nc-sa/4.0/
#!/bin/bash
# Nome: Denis Gerolini
# Email: denis.gerolini@datacare.it
# Licenza: Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)
# Per vedere una copia di questa licenza, visita http://creativecommons.org/licenses/by-nc-sa/4.0/

BPPLCLIENTS="/usr/openv/netbackup/bin/admincmd/bpplclients"
LOG="policy_log.txt"
BPTESTBPCD="/usr/openv/netbackup/bin/admincmd/bptestbpcd"

if [[ $EUID -ne 0 ]]; then
	echo "Lo script deve essere eseguito con privilegi di root"
	exit 1
fi

if [[ $# -ne 1 ]]; then
	echo "Inserire la lista composta nel seguente modo:"
	echo "hostname hardware os nome_policy"
	echo "**** LA POLICY DEVE ESSERE ESISTENTE ****"
	exit 1
fi

while read -r hst hardware os policy_name; do
	# Effettuo un ping di test per verificarne la raggiungibilità
	# Se uno di questi test dovesse fallire verrà loggato come WARNING ma inserito comunque nella policy per poter effettuare un troubleshooting
	#	successivamente.
	ping -c 1 ${hst} -W 2 &>/dev/null
	if [ $? -ne 0 ]; then
		echo "WARNING ${hst} PING FAILED" | tee -a ${LOG}
	else
		# Se il ping va a buon fine ne verifico la connettività con NetBackup
		${BPTESTBPCD} -client ${hst} &>/dev/null
		if [ $? -ne 0 ]; then
			echo "WARNING ${hst} bptestbpcd FAILED" | tee -a ${LOG}
		fi
	fi

	# Inserisco il client nella policy di backup LA POLICY DEVE ESSERE ESISTENTE
	${BPPLCLIENTS} ${policy_name} -add ${hst} ${hardware} ${os} &>/dev/null
	res=$?
	if [ $res -eq 0 ]; then
		echo "SUCCESS ${hst}" | tee -a ${LOG}
	else
		echo "FAILED ${hst} code ${res}" | tee -a ${LOG}
	fi
done < "$1"

exit 0
