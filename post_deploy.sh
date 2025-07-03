#############################
##RACCOLTA INFO POST DEPLOY##
#############################
#############################
####VP ShellScript###########
#############################
#########       #############
######            ###########
###       ⼭⻲            ###
#############################
#############################
#!/usr/bin/env basenv bash


#Author		: Valerio Passeri
#Contributor	: Denis Gerolini
#Version	: 2.0



#	Path principali NetBackup
OPENV="/usr/openv/"
DIR_NBU="${OPENV}netbackup/"
BIN="${DIR_NBU}bin/"
ADMINCMD="${BIN}admincmd/"
GOODIES="${BIN}goodies/"
SUPPORT="${BIN}support/"
DB="${OPENV}db/"
VOLMGR="${OPENV}volmgr/bin/"

#	Script principali NetBackup
BPNBAT="${BIN}bpnbat"
NBEMMCMD="${ADMINCMD}nbemmcmd"
VMOPRCMD="${VOLMGR}vmoprcmd"
VMRULE="${VOLMGR}vmrule"
VXLOGCFG="${BIN}vxlogcfg"
NBCERTCMD="${BIN}nbcertcmd"
NBDB_PING="${DB}bin/nbdb_ping"
BPPS="${BIN}bpps"
NBSECCMD="${ADMINCMD}nbseccmd"
NBAUDITREPORT="${ADMINCMD}nbauditreport"
BPDBJOBS="${ADMINCMD}bpdbjobs"
BPPLLIST="${ADMINCMD}bppllist"
BPPLINFO="${ADMINCMD}bpplinfo"
NBSTLUTIL="${ADMINCMD}nbstlutil"
NBSTL="${ADMINCMD}nbstl"
NBDEVQUERY="${ADMINCMD}nbdevquery"
NBCC="${SUPPORT}NBCC"
NBSU="${SUPPORT}nbsu"
NB_DEPLOYMENT_INSIGHTS="${ADMINCMD}netbackup_deployment_insights"

#	Definizione percorso di output
OUTPUT_FOLDER="output_$(date +"%d_%m_%Y")/"
POLICY_DETAILS="${OUTPUT_FOLDER}policy_details/"
NB_DEPLOY_FOLDER="${OUTPUT_FOLDER}nbgather_files"

# Definizione per il logging
LOG_ERROR_FILE="${OUTPUT_FOLDER}post_deploy_errors.log"


#	Lo script deve essere eseguito come root
if [ "${EUID}" -ne 0 ]; then
	echo "Lo script deve essere eseguito con i privilegi di root... esco"
	exit 1
fi

stdout_exit_status() {
	if [ $1 -eq 0 ]; then
		echo "SUCCESS"
	else
		echo "FAILED"
	fi
}

# 	Verifico se è stato effettuato il login con bpnbat
bpnbat_status=$( ${BPNBAT} -WhoAmI 2>>/dev/null)
if [ $? -eq 0 ]; then
	bpnbat_user=$( echo "${bpnbat_status}" | grep '^Web' -A 3 | awk '$1 == "Name:" {print $2}')
	echo ""
	echo "***********************************"
	echo "***********************************"
	echo "bpnbat login effettuato come utente ${bpnbat_user}... SUCCESS"
	echo "***********************************"
	echo "***********************************"
	echo ""

else

	echo "***********************************"
	echo "***********************************"
	echo 
	echo "WARNING: non hai effettuato il login bpnbat, alcune funzioni potrebbero non essere disponibili."
	while true; do
		read -p "Vuoi comunque proseguire [Y/N]? " continua
		continua=${continua,,}
		if [[ "${continua}" == "y" ]]; then
			echo ""
			echo "***********************************"
			echo "***********************************"
			echo "Continuo con l'esecuzione dello script senza aver effettuato il login bpnbat... WARNING"
			echo "***********************************"
			echo "***********************************"
			echo ""
			break
		elif [[ "${continua}" == "n" ]]; then
			echo "Esco!!"
			exit 0
		else
			echo "Scelta non valida..."
		fi
	done
	echo
	echo "***********************************"
	echo "***********************************"
fi	

# Creo cartella di output
mkdir -p ${OUTPUT_FOLDER}

#	Svuoto il file di log se già esiste
cat /dev/null > "${LOG_ERROR_FILE}"

# Copia bp.conf
echo -n "Copia di /usr/openv/netbackup/bp.conf... "
cp "${DIR_NBU}bp.conf" "${OUTPUT_FOLDER}" >/dev/null 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

# Copio output nbemmcmd
echo -n "Copio la lista host NBEMM... "
nbemmcmd_list_hosts=$(${NBEMMCMD} -listh 2>>"${LOG_ERROR_FILE}")
if [ $? -eq 0 ]; then
	echo "SUCCESS"
	echo "${nbemmcmd_list_hosts}" > ${OUTPUT_FOLDER}nbemmcmd.txt
	if echo "${nbemmcmd_list_hosts}" | grep -q '^master'; then
		
		machine_type="master"
	else
		machine_type="primary"
	fi
	echo -n  "Copio le configurazioni del ${machine_type} server... "
	${NBEMMCMD} -listsettings -machinename $(echo "${nbemmcmd_list_hosts}" | grep -Ei '^primary|^master' | awk '{print $2}') -machinetype ${machine_type} > ${OUTPUT_FOLDER}listemmsettings_audit.txt 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?
else
	echo "FAILED"
fi




# Media server e drive status
echo -n "Verifica status media e drive... "
${VMOPRCMD} > "${OUTPUT_FOLDER}vmoprcmd.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

# Verifica spazio filesystem
echo -n "Verifica spazio filesystem... "
df -h > "${OUTPUT_FOLDER}df_h.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

# Verifica parametri di logging di default di vxlog
echo -n "Verifica valori di default di vxlog... "
${VXLOGCFG} -p nb -o default -l > "${OUTPUT_FOLDER}vxlogcfg.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

# Verifica se il DB NB è UP
echo -n "Verifica lo stato di NBDB... "
${NBDB_PING} > "${OUTPUT_FOLDER}nbdb_ping.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

# Recupero le informazioni sui certificati
echo -n "Recupero informazioni dei certificati a livello di dominio... "
${NBCERTCMD} -listAllDomainCertificates > "${OUTPUT_FOLDER}certs_domain.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?
echo -n "Recupero informazioni dei certificati presenti sul Primary Server... "
${NBCERTCMD} -listAllcertificates > "${OUTPUT_FOLDER}cert_list.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?


# Esecuzione del comando vmrule
echo -n "Eseguo VMRULE... "
${VMRULE} -listall >"${OUTPUT_FOLDER}vmrules.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

# Verifica dei servizi attivi
echo -n "Verifica dei servizi NetBackup attivi... "
${BPPS} -x > "${OUTPUT_FOLDER}bpps_x.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?



# Verifico le impostazioni di rete
echo -n "Verifico le impostazioni di rete... "
if command -v ip &>/dev/null; then
	ip a > "${OUTPUT_FOLDER}ip_all.txt" 2>>"${LOG_ERROR_FILE}"
	ip r > "${OUTPUT_FOLDER}ip_route.txt" 2>>"${LOG_ERROR_FILE}"
else command -v ifconfig &>/dev/null
	ifconfig > "${OUTPUT_FOLDER}ifconfig.txt" 2>>"${LOG_ERROR_FILE}"
	route > "${OUTPUT_FOLDER}route.txt" 2>>"${LOG_ERROR_FILE}"
fi
stdout_exit_status $?

echo -n "Verifica memoria RAM... "
free -h > "${OUTPUT_FOLDER}free_h.txt"
stdout_exit_status $?


echo -n "Verifica memoria virtuale... "
vmstat -s > "${OUTPUT_FOLDER}vmstat.txt"
stdout_exit_status $?

echo -n "Copio il file /etc/passwd... "
if cp /etc/passwd "${OUTPUT_FOLDER}" 2>>"${LOG_ERROR_FILE}"; then
	echo "SUCCESS"
else
	echo "FAILED"
fi

echo -n "Copio il file /etc/group... "
if cp /etc/group "${OUTPUT_FOLDER}" 2>>"${LOG_ERROR_FILE}"; then
	echo "SUCCESS"
else
	echo "FAILED"
fi


echo -n "Copio il file /etc/hosts... "
if cp /etc/hosts "${OUTPUT_FOLDER}" 2>>"${LOG_ERROR_FILE}"; then
	echo "SUCCESS"
else
	echo "FAILED"
fi

echo -n "Copio il file /etc/resolv.conf... "
if cp /etc/resolv.conf "${OUTPUT_FOLDER}" 2>>"${LOG_ERROR_FILE}"; then
	echo "SUCCESS"
else
	echo "FAILED"
fi

echo -n "Copio il file /etc/fstab... "
if cp /etc/fstab "${OUTPUT_FOLDER}" 2>>"${LOG_ERROR_FILE}"; then
	echo "SUCCESS"
else
	echo "FAILED"
fi

echo -n "Eseguo il NetBackup Security Configuration service utility (nbseccmd)... "
${NBSECCMD} -getsecurityconfig -auditretentionperiod > "${OUTPUT_FOLDER}auditreport_retention.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

echo -n "Estrapolo il report di audit (nbauditreport) dal 1 gennaio 2000... "
${NBAUDITREPORT} -sdate 01/01/2000 -notruncate > "${OUTPUT_FOLDER}auditreport_retention.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

echo -n "Estrapolo il report di audit dettagliato (nbauditreport) dal 1 gennaio 2000... "
${NBAUDITREPORT} -sdate 01/01/2000 -notruncate -fmt DETAIL > "${OUTPUT_FOLDER}auditreport_details.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

echo -n "Interrogo il database dei job... "
${BPDBJOBS} -summary > "${OUTPUT_FOLDER}summary_jobs.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

echo -n "Scarico la lista delle policy... "
${BPPLLIST} > "${OUTPUT_FOLDER}lista_policy.txt" 2>>"${LOG_ERROR_FILE}"
if [ $? -eq 0 ]; then
	echo "SUCCESS"
	mkdir -p "${POLICY_DETAILS}"
	echo "Scarico il dettaglio delle policy... "
	detail_failed=0
	for policy in $(cat ${OUTPUT_FOLDER}lista_policy.txt); do
		echo -e -n "\tDownload dettaglio policy ${policy}... "
		${BPPLINFO} ${policy} -L > "${POLICY_DETAILS}${policy}.info" 2>>"${LOG_ERROR_FILE}"
		if [ $? -eq 0 ]; then
			echo "SUCCESS"
		else
			echo "FAILED"
			$(( detail_failed + 1 ))
		fi
	done
else
	echo "FAILED"
fi

echo -n "Report SLP... "
${NBSTLUTIL} report > "${OUTPUT_FOLDER}slp_backlog.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

echo -n "Download lista SLP... "
${NBSTL} -L > "${OUTPUT_FOLDER}slp_list.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

echo -n "Download lista versioni SLP... "
${NBSTL} -L -all_versions > "${OUTPUT_FOLDER}slp_list_all_versions.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

echo -n "Download lista Disk Pool presenti... "
${NBDEVQUERY} -listdp -U > "${OUTPUT_FOLDER}dpool_list.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

echo -n "Download lista Storage Server presenti... "
${NBDEVQUERY} -liststs -L > "${OUTPUT_FOLDER}storage_pool.txt" 2>>"${LOG_ERROR_FILE}"
stdout_exit_status $?

echo -n "Eseguo NBCC, attendi... "
${NBCC} -nocleanup >/dev/null 2>>"${LOG_ERROR_FILE}"
if [ $? -eq 0 ]; then
	echo "SUCCESS"
	mv output "${OUTPUT_FOLDER}nbcc_output" 2>"${LOG_ERROR_FILE}"
else
	echo "FAILED"
fi

echo -n "Eseguo nbsu, attendi... "
nbsu_stdout=$( ${NBSU} 2>>"${LOG_ERROR_FILE}")
if [ $? -eq 0 ]; then
	echo "SUCCESS"
	mv $( echo "${nbsu_stdout}" | tail | grep '^Final NBSU output' | awk '{print $NF}' ) "${OUTPUT_FOLDER}"
	echo "${nbsu_stdout}" > "${OUTPUT_FOLDER}nbsu_log.txt"
else
	echo "FAILED"
fi


echo -e "\n***********************************"
echo "Devo eseguire netbackup_deployment_insights, inserisci alcuni dati e attendi il completamento..."
${NB_DEPLOYMENT_INSIGHTS} --gather --report --capacity --hoursago 8766 2>>"${LOG_ERROR_FILE}"
if [ $? -eq 0 ]; then
	echo "nb_deployment_insight terminato con successo"
	report_path="/usr/openv/var/global/reports"
	last_report="$(ls -td "${report_path}"/*/ | head -n 1 )"
	tar czf "${OUTPUT_FOLDER}nb_deployment_insights_report.tgz" ${last_report}
else
	echo "Errore durante l'esecuzione di nb_deployment_insight"
fi
echo -e "***********************************\n"

tarout="${OUTPUT_FOLDER%/}"
tar czf "${tarout}.tgz" "${OUTPUT_FOLDER}" 2>> "${LOG_ERROR_FILE}"
if [ $? -ne 0 ]; then
	echo "ERROR, non sono riuscito a creare l'archivio dei report presenti in ${OUTPUT_FOLDER}"
	exit 1
fi

echo  -e "\n###############################################################################################################################"
echo  "####### Scritp terminato, è stato creato il file ${tarout}.tgz nella directory corrente contenente tutti i report"
echo  -e "###############################################################################################################################\n"
echo ""
if [ -s "${LOG_ERROR_FILE}" ]; then
	echo "Verifica eventuali errori nel file ${LOG_ERROR_FILE}"
fi

exit 0
