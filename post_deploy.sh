
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

# Preferirei fornire delle variabili con indirizzi assoluti piuttosto che esportare il PATH
export PATH=$PATH:/usr/openv/netbackup/bin:/usr/openv/netbackup/bin/admincmd:/usr/openv/netbackup/bin/goodies:/usr/openv/netbackup/bin/support:/usr/openv/volmgr/bin

# Preferirei raccogliere gli output in una cartella presente nello stesso path dello script, è più facile andarli a recuperare
DIR_OUT="/tmp/raccolta_dati_nbu_$(date +"%m_%d_%Y")"
DIR_ZIP="/tmp/raccolta_dati_nbu_$(date +"%m_%d_%Y").tar"
DIR_NBU="/usr/openv/netbackup"

# Preferirei già aver effettuato il login dato che successivamente viene richiesto comunque, ma verificherei l'utente che comunque lancia lo script (deve essere root)
# Prompt iniziale per il login con loop per input valido
while true; do
    read -p "Prima di eseguire questo script, se ti trovi su NetBackup 10.5 o superiore, devi eseguire il login con il comando:
bpnbat -login -loginType WEB

Se non lo hai fatto, rispondi 'n', esegui il login e rilancia questo script. Altrimenti premi 'y' per continuare: " proceed

    if [[ "$proceed" == "y" || "$proceed" == "Y" ]]; then
        echo "Proseguo con l'esecuzione dello script..."
        break
    elif [[ "$proceed" == "n" || "$proceed" == "N" ]]; then
        echo "Prima di rilanciare lo script, esegui il login con il comando: bpnbat -login -loginType WEB"
        exit 1
    else
        echo "Input non valido. Rispondi con 'y' o 'n'."
    fi
done

echo "stiamo raccoglinedo tutti i dati..."
echo "creo una cartella temporanea sotto tmp"
mkdir -p $DIR_OUT
echo "raccolgo bp.conf"
cp ${DIR_NBU}/bp.conf ${DIR_OUT}
echo "raccolgo configurazione NBU"
nbemmcmd -listh > ${DIR_OUT}/nbemmcmd.txt
nbemmcmd -listsettings -machinename $(nbemmcmd -listh | grep ^primary | awk '{print $2}') -machinetype primary > ${DIR_OUT}/listemmsettings_audit.txt
vmoprcmd > ${DIR_OUT}/vmoprcmd.txt
df -h > ${DIR_OUT}/df_h.txt
vxlogcfg -p nb -o default -l > ${DIR_OUT}/vxlogcfg.txt
/usr/openv/db/bin/nbdb_ping > ${DIR_OUT}/nbdb_ping.txt
nbcertcmd -listAllDomainCertificates > ${DIR_OUT}/Certs_Domain.txt
nbcertcmd -listAllcertificates > ${DIR_OUT}/Certs_Lists.txt
vmrule -listall >  ${DIR_OUT}/vmrules.txt
date > ${DIR_OUT}/bpps.txt ; bpps -x >> ${DIR_OUT}/bpps.txt

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
