#!/bin/bash

# This script automates disabling, deleting or deleting + archiving user accounts

# Function to print usage statment on error
usage() {
  echo "Usage: ${0} [-dra] username [...]" >&2
  echo 'Disable, delete or delete & archive user accounts'
  echo 'With no options the default is to disable the given account'
  echo ' -d Delete user account'
  echo ' -r Delete user account & remove user home directory'
  echo ' -a Archive home directory, delete user account & remove home directory'
  exit 1
}

# Function to perform disable, delete, archive user
remove_user() {
  local TO_BE_DONE="${1}"
  local USER="${2}"
  case "${TO_BE_DONE}"  in
    disable)
      chage -E0 "${USER}"
      success_check 'disable account' "${USER}" "${?}"
      ;;
    delete)
      userdel "${USER}"
      success_check 'deletion' "${USER}" "${?}"
      ;;
    delete_remove)
      userdel -r "${USER}"
      success_check 'deletion and directory removal' "${USER}" "${?}"
      ;;
    archive_delete_remove)
      if [[ ! -d /archives ]]; then
          mkdir /archives
      fi
      tar -czvf "/archives/${USER}-homedir-$(date +%s).tar.gz" /home/${USER}
      success_check 'home directory archiving' "${USER}" "${?}"
      userdel -r "${USER}"
      success_check 'deletion and directory removal' "${USER}" "${?}"
      ;;
  esac
}

# Function to check if commands have succeeded & Print accordingly
success_check() {
  local ACTION="${1}"
  local USER="${2}"
  local RESULT="${3}"
  if [[ "${RESULT}" -eq 0 ]]; then
    echo "${USER} ${ACTION} was successful."
  else
    echo "Failure - ${USER} ${ACTION} was unsuccessful." >&2
  fi
}

# Check that the script is being run with root priveleges
if [[ "${UID}" -ne 0 ]]; then
  echo "Please run with root priveleges" >&2
  exit 1
fi

# Set script variables
WHAT_TO_DO='disable'

# Assess options selected by user
while getopts dra OPTION
do
  case ${OPTION} in
    d)
      WHAT_TO_DO='delete'
      ;;
    r)
      WHAT_TO_DO='delete_remove'
      ;;
    a)
      WHAT_TO_DO='archive_delete_remove'
      ;;
    ?)
      usage
      ;;
  esac
done
# Remove option-parameters from parameters
if [[ ${OPTIND} -gt 1 ]]; then
  shift "$(( OPTIND - 1 ))"
fi

# Check at least one username was provided
if [[ "${#}" -lt 1 ]]; then
  usage
fi

# Check username exists and isnt a system id
while [[ "${#}" -gt 0 ]]
do
  USERNAME="${1}"
  if [[ $(grep -c "${USERNAME}" /etc/passwd) -eq 1 ]]; then
    if [[ $(id -u "${USERNAME}") -gt 1000 ]]; then
      remove_user "${WHAT_TO_DO}" "${USERNAME}"
      shift
    else
      echo "Failure - ${USERNAME} is a system account" >&2
      echo "System accounts must be removed by a system administrator" >&2
      echo
      shift
    fi
  else
    echo "Failure - ${USERNAME} does not exist"
    echo
    shift
  fi
done
exit 0
