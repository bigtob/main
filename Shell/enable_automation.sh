#!/bin/bash
##############################################################################
#
# Version:      Name:           Date:           Comments:
# 0.1           BigTob          30/11/2018      Initial
# 0.2           BigTob          23/01/2019      Fixed minor bug with variable expansion in sed statement for allhosts
###############################################################################

###############################################################################
# This script configures the default hosts file for Ansible to accepted standards
###############################################################################

### Variables/arrays
hostfile=/etc/ansible/hosts
hostarray=()
goodhostarray=()
loop=1

### Colours
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'

### Get project user input
while true
do
  echo -n "${grn}Input${end} Please enter the project name (e.g. GIS|OATS|NetworksMaximo etc.): " 
  read project
  if [[ ! -z $project ]]
  then
    break
  fi
done

### Get envname user input
while true
do
  echo -n "${grn}Input${end} Please enter the environment name (e.g. DEV|TST|UAT|PRE|PRD etc.): "
  read envname
  if [[ ! -z $envname ]]
  then
    break
  fi
done

### Get/validate number of hosts user input
while true
do
  echo -n "${grn}Input${end} Please enter the number of hosts you wish to enable: "
  read number
  re='^[0-9]+$'
  if [[ $number =~ $re ]] 
  then
    break
  fi
done

### Get hostname user input
while [ ${loop} -le ${number} ]
do
  echo -n "${grn}Input${end} Please enter hostname ${loop}: "
  read name
  if [[ ! -z $name ]]
  then 
    hostarray+=( ${name} )
    loop=$[$loop + 1]
  else
    loop=$loop
  fi
done
  
### Check all hosts are in dns
for x in "${hostarray[@]}"
do
  nslookup ${x} >/dev/null
  [ $? -eq 0 ] && goodhostarray+=( ${x} ) || echo "${yel}Warn${end} Host \"${x}\" does not resolve in DNS - skipping"
done

### Create Ansible host file stanza header for project and env
header="$(echo -n ${project} | tr [:upper:] [:lower:] ; echo ${envname} | tr [:upper:] [:lower:])"
if ! grep ${header} ${hostfile} >/dev/null
then
  echo "" >> ${hostfile}
  echo [${header}] >> ${hostfile}
else
  echo -e "${yel}Warn${end} \"${header}\" already exists in ${hostfile} - skipping"
fi

### Add valid user inputted hosts under the project and env header
### Also add to [allhosts] stanza as applicable
for x in "${goodhostarray[@]}"
do
  if [[ -z $(eval "awk -v RS='' '/"${header}"/'" ${hostfile} | grep ^${x}) ]]
  then
    echo "${cyn}Info${end} Adding \"${x}\" to ${hostfile} under header \"[${header}]\""
    sed -i "/${header}/ a ${x} type=cloud proj=${project}" ${hostfile}
  else
    echo "${yel}Warn${end} Host \"${x}\" already exists under header \"[${header}]\" - skipping"
  fi
  if [[ -z $(awk -v RS='' '/allhosts/' ${hostfile} | grep ^${x}) ]]
  then
    echo "${cyn}Info${end} Adding \"${x}\" to ${hostfile} under header \"[allhosts]\""
    sed -i "/allhosts/ a ${x} type=cloud" ${hostfile}
  else
    echo "${yel}Warn${end} Host \"${x}\" already exists under header \"[allhosts]\" - skipping"
  fi
done

### Print out stanza
echo "${cyn}Info${end} ${hostfile} for ${header} configured as:"
eval "awk -v RS='' '/"${header}"/'" ${hostfile} | while read line
do
  echo -e "\t $line"
done
echo "${cyn}Info${end} You can now run automation against your ${number} hosts either individually or simultaneously:" 
echo -e "\t ansible-playbook myplaybook.yml -e \"host=${goodhostarray[0]}\""
echo -e "\t ansible-playbook myplaybook.yml -e \"host=${header}\""
