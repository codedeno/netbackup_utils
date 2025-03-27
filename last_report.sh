#!/bin/bash
#Author		: Denis Gerolini
#Email		: denis.gerolini@datacare.it

#Descrizione:
#	** tool non ufficiale Veritas, potrebbero esserci dei bug e riportare dati errati, quindi da utilizzare sempre e soltanto come strumento di ausilio **
#Lo script esegue una verifica degli host "conosciuti da Veritas NetBackup". Per conosciuti si intende qualsiasi host inserito in una policy di backup, anche non attiva.
#Questo può inoltre significare che, pur essendo inserito in una policy di backup, potrebbe non essere stato installato il software Veritas. Ad esempio una VM VMWare, 
#che sfrutta una modalità di backup agentless, potrebbe essere presente nella lista ma fallire la connessione con NetBackup.
#
#1 - Lo script recupera la lista di policy salvate su NetBackup e verifica quali sono i client associati a quella policy.
#2 - Il server NetBackup interroga il clientper verificare se è presente il software Veritas
#3 - Se il software è installato e avviene la comunicazione allora viene marcato come "SUCCESS", "FAILED" se non è presente il client o vi sono problemi di comunicazione

CLIENTS="/usr/openv/netbackup/bin/admincmd/bpplclients"
POLICIES="/usr/openv/netbackup/bin/admincmd/bppllist"
POLICY_INFO="/usr/openv/netbackup/bin/admincmd/bpplinfo"
BPTEST="/usr/openv/netbackup/bin/admincmd/bptestbpcd"
OUTPUT="$( date +%d%m%Y)_report.csv"

#	Flag modalità verbose
VERBOSE=0


if [[ "${EUID}" -ne 0 ]]; then
	echo "WARNING -- devi eseguire lo script come root -- WARNING"
fi

#	Modalità verbose.
start_time=$( date )
if [[ "${1}" == "-v" ]]; then
	VERBOSE=1
	echo "*************************************************"
	echo "INFO 		--> Verbose MODE"
	echo "Output file 	--> ${OUTPUT}"
	echo "Start time	--> ${start_time}"
	echo "*************************************************"
fi

#	Lista client che effettuano la connessione con NetBackup
connected=()
#	Lista client che falliscono la connessione con NetBackup
not_connected=()
#	Lista delle policy da escludere, in futuro può essere possibile inizializzarla da file
exclude_list=("Install_Policy_Linux" "Install_Policy_Windows")

#	Header del report
echo "Policy name, Policy type, client name, BPTESTBPCD" > "${OUTPUT}"

for policy in $( ${POLICIES} ); do
#	Questa condizione iniziale potrebbe essere rimossa, ma nel nostro caso specifico è stata inclusa dato che le due policy in oggetto
#		sono state create per uno scopo di servizio.
	if [[ "${exclude_list[@]}" =~ "${policy}" ]]; then
		continue
	fi


	if [[ "${VERBOSE}" -eq 1 ]]; then
		echo "Policy name: ${policy}"
	fi
	policy_type=$( ${POLICY_INFO} ${policy} -L | grep '^Policy Type:' | awk '{print $3}' )
	for client in $( ${CLIENTS} ${policy} | awk ' NR > 2 {print $3}' ); do

		if [[ "${VERBOSE}" -eq 1 ]]; then
			echo -en "\t${client} NetBackup connection... "
		fi

		if [[ "${connected[@]}" =~ "${client}" ]]; then
			echo "${policy}, ${policy_type}, ${client}, SUCCESS" >> "${OUTPUT}"
			if [[ "${VERBOSE}" -eq 1 ]]; then
				echo "SUCCESS"
			fi

		elif [[ "${not_connected[@]}" =~ "${client}" ]]; then
			echo "${policy}, ${policy_type}, ${client}, FAILED" >> "${OUTPUT}"
			if [[ "${VERBOSE}" -eq 1 ]]; then
				echo "FAILED"
			fi

		else
			${BPTEST} -client "${client}" -connect_timeout 300 &>/dev/null
			if [ $? -eq 0 ]; then
				connected+=("${client}")
				echo "${policy}, ${policy_type}, ${client}, SUCCESS" >> "${OUTPUT}"
				if [[ "${VERBOSE}" -eq 1 ]]; then
					echo "SUCCESS"
				fi

			else
				not_connected+=("${client}")
				echo "${policy}, ${policy_type}, ${client}, FAILED" >> "${OUTPUT}"
				if [[ "${VERBOSE}" -eq 1 ]]; then
					echo "FAILED"
				fi

			fi
		fi	
	done
done
if [[ "${VERBOSE}" -eq 1 ]]; then
	size_connected=${#connected[@]}
	size_not_connected=${#not_connected[@]}
	client_totali=$(( size_connected + size_not_connected ))
	echo "*************************************************"
	echo "Output file 	--> ${OUTPUT}"
	echo "Client totali	--> ${client_totali}"
	echo "Start time	--> ${start_time}"
	echo "End time 		--> $( date )"
	echo "*************************************************"
fi
