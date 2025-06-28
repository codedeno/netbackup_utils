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
#!/bin/bash
#
# In linea di massima lo script è ok, ma bisogna effettuare dei cambiamenti importanti:
#    1 - gestione degli errori, quando uno script termina e non ha raccolto nulla dobbiamo saperlo 
#    2 - file di log, gli errori devono essere loggati
#    3 - raccolta output sotto lo stesso path dello script
#


##################################	DENIS
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

#	Definizione percorso di output e file di log
OUTPUT_FOLDER="output_$(date +"%d_%m_%Y")/"
LOG_FILE="${OUTPUT_FOLDER}post_deploy.log"
##################################	END DENIS

##################################	DENIS
# Verifico se è stato effettuato il login con bpnbat
bpnbat_status=$( ${BPNBAT} -WhoAmI 2>/dev/null)
if [ $? -eq 0 ]; then
	echo "Hai già effettuato il login come utente $( echo "${bpnbat_status}" | awk '$1 == "Name:" {print $2}'), continuo..."
else
	echo "WARNING: non hai effettuato il login bpnbat, alcune funzioni potrebbero non essere disponibili."
fi	

# Creo cartella di output
mkdir -p ${OUTPUT_FOLDER}

# Copia bp.conf
echo -n "Copia di /usr/openv/netbackup/bp.conf... "
cp "${DIR_NBU}bp.conf" "${OUTPUT_FOLDER}"
if [ $? -eq 0 ]; then
	echo "SUCCESS"
else
	echo "FAILED"
fi

# Copio output nbemmcmd
echo -n "Copio la lista host NBEMM... "
nbemmcmd_list_hosts=$(${NBEMMCMD} -listh 2>/dev/null)
if [ $? -eq 0 ]; then
	echo "SUCCESS"
	echo "${nbemmcmd_list_hosts}" > ${OUTPUT_FOLDER}nbemmcmd.txt
	if echo "${nbemmcmd_list_hosts}" | grep -q '^master'; then
		machine_type="master"
	else
		machine_type="primary"
	fi
	echo -n  "Copio le configurazioni del ${machine_type} server... "
	${NBEMMCMD} -listsettings -machinename $(echo "${nbemmcmd_list_hosts}" | grep -Ei '^primary|^master' | awk '{print $2}') -machinetype ${machine_type} > ${OUTPUT_FOLDER}listemmsettings_audit.txt 2>errori.txt
	if [ $? -eq 0 ]; then
		echo "SUCCESS"
	else
		echo "FAILED"
	fi
else
	echo "FAILED"
fi




# Media server e drive status
echo -n "Verifica status media e drive... "
${VMOPRCMD} > "${OUTPUT_FOLDER}vmoprcmd.txt" 2>/dev/null
if [ $? -eq 0 ]; then
	echo "SUCCESS"
else
	echo "FAILED"
fi

# Verifica spazio filesystem
echo -n "Verifica spazio filesystem... "
df -h > "${OUTPUT_FOLDER}df_h.txt" 2>/dev/null
if [ $? -eq 0 ]; then
	echo "SUCCESS"
else
	echo "FAILED"
fi

# Verifica parametri di logging di default di vxlog
echo -n "Verifica valori di default di vxlog... "
${VXLOGCFG} -p nb -o default -l > "${OUTPUT_FOLDER}vxlogcfg.txt" 2>/dev/null
if [ $? -eq 0 ]; then
	echo "SUCCESS"
else
	echo "FAILED"
fi

# Verifica se il DB NB è UP
echo -n "Verifica lo stato di NBDB... "
${NBDB_PING} > "${OUTPUT_FOLDER}nbdb_ping.txt" 2>errori.txt
if [ $? -eq 0 ]; then
	echo "SUCCESS"
else
	echo "FAILED"
fi

# Recupero le informazioni sui certificati
echo -n "Recupero informazioni dei certificati a livello di dominio... "
${NBCERTCMD} -listAllDomainCertificates > "${OUTPUT_FOLDER}certs_domain.txt" 2>errori.txt
if [ $? -eq 0 ]; then
	echo "SUCCESS"
else
	echo "FAILED"
fi
echo -n "Recupero informazioni dei certificati presenti sul Primary Server... "
${NBCERTCMD} -listAllcertificates > "${OUTPUT_FOLDER}cert_list.txt" 2>errori.txt
if [ $? -eq 0 ]; then
	echo "SUCCESS"
else
	echo "FAILED"
fi


# Esecuzione del comando vmrule
echo -n "Eseguo VMRULE... "
${VMRULE} -listall >"${OUTPUT_FOLDER}vmrules.txt" 2>errori.txt
if [ $? -eq 0 ]; then
	echo "SUCCESS"
else
	echo "FAILED"
fi

# Verifica dei servizi attivi
echo -n "Verifica dei servizi NetBackup attivi... "
${BPPS} -x > "${OUTPUT_FOLDER}bpps_x.txt" 2>errori.txt
if [ $? -eq 0 ]; then
	echo "SUCCESS"
else
	echo "FAILED"
fi

# Verifico le impostazioni di rete
echo -n "Verifico le impostazioni di rete... "
if command -v ip &>/dev/null; then
	echo "esi"
	ip 
elif command -v ifconfig &>/dev/null
	echo "ifconfig"
else
fi

exit 0

# Non è detto che il comando ip sia presente
ip a > ${DIR_OUT}/ip.txt
ip r > ${DIR_OUT}/route.txt

# Questo comando non va bene, o meglio potrebbe anche andare bene ma non è detto che utilizzi Network Manager
nmcli > ${DIR_OUT}/nmcli.txt
date > ${DIR_OUT}/memory.txt ; free -h >> ${DIR_OUT}/memory.txt
date > ${DIR_OUT}/vmstat.txt ; vmstat -s >> ${DIR_OUT}/vmstat.txt
cat /etc/passwd | grep -i nb > ${DIR_OUT}/nb_users.txt
cat /etc/group | grep -i nb > ${DIR_OUT}/nb_groups.txt
cp /etc/hosts ${DIR_OUT}/hosts
cp /etc/resolv.conf ${DIR_OUT}/resolv.conf
cp /etc/fstab ${DIR_OUT}/fstab
nbseccmd -getsecurityconfig -auditretentionperiod > ${DIR_OUT}/auditreport_retention.txt
nbauditreport -sdate 01/01/2000 -notruncate > ${DIR_OUT}/auditreport_summary.txt
nbauditreport -sdate 01/01/2000 -notruncate -fmt DETAIL > ${DIR_OUT}/auditreport_details.txt
bpdbjobs -summary > ${DIR_OUT}/summary_jobs.txt
bppllist > ${DIR_OUT}/lista_policy.txt
for i in ${DIR_OUT}/lista_policy.txt; do bpplinfo $i -L >> ${DIR_OUT}/dettaglio_policy.txt; echo "------------------" >> ${DIR_OUT}/dettaglio_policy.txt; done
nbstlutil report > ${DIR_OUT}/backlog_SLP.txt
nbstl -L > ${DIR_OUT}/lista_SLP.txt
nbstl -L -all_versions > ${DIR_OUT}/lista_SLP_ALLVERSIONS.txt
nbdevquery -listdp -U > ${DIR_OUT}/diskpool_list.txt
nbdevquery -liststs -L > ${DIR_OUT}/storage_server_list.txt


# NBCC e nbsu, non c'è modo di utilizzare una funzione nativa per l'output? Ad esempio redirigendo direttamente e nativamente un file nella cartella desiderata
echo "raccolgo NBCC"
NBCC -nocleanup > ${DIR_OUT}/nbcc_log
cp -r $(tail -2 ${DIR_OUT}/nbcc_log | grep out | awk '{print $1}') ${DIR_OUT}/

echo "raccolgo nbsu"
nbsu &> ${DIR_OUT}/nbsu_log.txt
cp -r $(cat ${DIR_OUT}/nbsu_log.txt | grep Final | awk '{print $6}') ${DIR_OUT}/

echo "##################################################"
echo "Ora lancio nbdeployutil con info sull'ultimo anno, sono richieste le informazioni per continuare..."
data=$(date +"%Y%m%d_%H")
nbdeployutil --gather --report --capacity --hoursago 8766

wait
for i in `ls /usr/openv/var/global/reports/${data}*/report-capacity-*.xls`;
do
cp $i "${DIR_OUT}"
done

echo "File xls del nbdeployutil copiato in ${DIR_OUT}"

echo "##################################################"
echo "##################################################"
echo "ABBIAMO RACCCOLTO TUTTI I DATI, ora creo il tar..."
echo "##################################################"
echo "##################################################"
tar cvf $DIR_ZIP $DIR_OUT
echo "##################################################"
echo "##################################################"
echo "PUOI PORTARE VIA IL TAR $DIR_ZIP"
echo "##################################################"
echo "##################################################"
