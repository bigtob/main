#!/bin/bash
##############################################################################
#
# Version:      Name:           Date:           Comments:
# 0.1           BigTob          25/06/2019      Initial
###############################################################################

###############################################################################
# This script displays purpose information for Ansible playbooks
###############################################################################

### Variables
basedir=/software/GIT_repositories/Cloud-Integration/_Common/Ansible/Linux/
flag=$1

### Colours
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'

### Functions

# Usage statement
usage ()
{
  echo "Usage: $0 [-l]"
  exit $1
}

# Playbook list function
fn_list_playbooks ()
{
  for dir in standardbuild nonstandardbuild maintenance adhoc
  do
    printf "%-30s\n" "${cyn}$dir playbooks${end}"
    cd $basedir$dir
    for playbook in $(find . -maxdepth 1 -name "*.yml" | grep -v roles)
    do
      purpose=$(grep ^"# PURPOSE:" $playbook | awk -F: '{print $2}' | cut -c2-)
      syntax=$(grep ^"# SYNTAX:" $playbook | awk -F: '{print $2}' | cut -c2-)
      [[ $syntax == "" ]] && syntax="SYNTAX not defined"
      if [[ $purpose == "" ]]
      then
        if [[ $flag == "-l" ]]
        then
          printf "%-40s %-30s\n" "$(echo $playbook | cut -c3-)" "${red}PURPOSE not defined${end}"
          printf "%-100s\n" "${blu}  \- $syntax${end}"
        else
          printf "%-40s %-30s\n" "$(echo $playbook | cut -c3-)" "${red}PURPOSE not defined${end}"
        fi
      elif [[ $purpose =~ CAUTION ]]
      then
        if [[ $flag == "-l" ]]
        then
          printf "%-40s %-30s\n" "$(echo $playbook | cut -c3-)" "${yel}$purpose${end}"
          printf "%-100s\n" "${blu}  \- $syntax${end}"
        else
          printf "%-40s %-30s\n" "$(echo $playbook | cut -c3-)" "${yel}$purpose${end}"
        fi
      else
        if [[ $flag == "-l" ]]
        then
          printf "%-40s %-30s\n" "$(echo $playbook | cut -c3-)" "${grn}$purpose${end}"
          printf "%-100s\n" "${blu}  \- $syntax${end}"
        else
          printf "%-40s %-30s\n" "$(echo $playbook | cut -c3-)" "${grn}$purpose${end}"
        fi
      fi
    done
    echo ""
  done
}

fn_list_playbooks
