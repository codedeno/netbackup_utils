#!/bin/bash
# Nome: Denis Gerolini
# Email: denis.gerolini@datacare.it
# Licenza: Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)
# Per vedere una copia di questa licenza, visita http://creativecommons.org/licenses/by-nc-sa/4.0/

BP_TEST="/usr/openv/netbackup/bin/admincmd/bptestbpcd"
BP_GETCONFIG="/usr/openv/netbackup/bin/admincmd/bpgetconfig"
report_file="dc_client_report.csv"

echo "Hostname, ping, IP, OS Version, OS, BPTEST,NB Version" > "${report_file}"

bpplclients -allunique -noheader | sort -k3 | uniq | while read -r os version hst unk; do
        #       Interrogo NSLOOKUP per recuperare l'indirizzo IP
        echo "***** ${hst} *****"
        host_ip=$(nslookup ${hst} | grep -E '^Address:' | awk 'NR == 2 {print $2}')
        if [[ -z "${host_ip}" ]]; then
        #       Se l'indirzzo non è stato recuperato fallisce il ciclo per questo host e passo al prossimo
                echo "NSLOOKUP FAILED  ${hst}"
                echo "${hst}, FAILED, FAILED, ${version}, ${os}, FAILED, FAILED" >> "${report_file}"
        else
        #       Indirizzo recuperato testo il ping
                ping -c 1 -w 2 ${hst} &>/dev/null
                ping_result=$?
                if [ ${ping_result} -ne 0 ]; then
        #       Fallisce il ping, riporto e passo al prossimo host
                        echo "PING FAILED  ${hst}"
                        echo "${hst}, FAILED, ${host_ip},${version}, ${os},FAILED, FAILED" >> "${report_file}"
                else
        #       Il ping va a buon fine, procedo con il bptest
                        ${BP_TEST} -client ${hst} &>/dev/null
                        bptest_result=$?
                        if [ ${bptest_result} -ne 0 ]; then
                                echo "BPTEST FAILED  ${hst}"
                                echo "${hst}, SUCCESS, ${host_ip},${version}, ${os}, FAILED, FAILED" >> "${report_file}"
                        else
        #       Stampo il report
                                nb_version=$(${BP_GETCONFIG} -M ${hst} | grep VERSIONINFO | awk '{print $7}' | tr -d '"')
                                echo "TEST SUCCESS ${hst}"
                                echo "${hst}, SUCCESS, ${host_ip},${version}, ${os}, SUCCESS, ${nb_version}" >> "${report_file}"
                        fi
                fi
        fi
done
