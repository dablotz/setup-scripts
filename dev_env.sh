#! /usr/bin/env bash

set -o errexit
set -o pipefail

# Check if homebrew (brew) is installed
# If yes update brew, otherwise install from the internet
function check_brew() {
  if ! brew >/dev/null 2>&1; then
    echo "Brew found. Updating brew"
    if ! brew update; then
      echo "Unable to update brew. Exiting"
      return 1
    fi
  else
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      echo "Brew installed. Continuing to packages"
    else
      echo "Unable to install brew. Exiting"
      return 1
    fi
  fi
}

# Uses homebrew to install command line apps
function install_apps() {
  for package in "${packages[@]}"; do
    if brew list "${package}" >/dev/null 2>&1; then
      echo "Brew has already installed ${package}. Updating ${package}"
      brew upgrade ${package}
    else
      echo "Brew cannot find ${package}. Installing ${package}"
      brew install ${package}
    fi
  done
}

#Uses pyenv to install python
function install_python() {
  if ! pyenv >/dev/null 2>&1; then
    if [ -n "$(pyenv versions | grep ${python_version})" ]; then
      echo "python ${python_version} found. Not installing python ${python_version}"
    else
      pyenv install "${python_version}"
    fi
  else
    echo "pyenv unavailable"
  fi
}

# Updates the user's shell profile file to include pyenv
function update_profile() {
  changes_made=0
  
  if [[ -n ${SHELL} ]]; then
    profile="${HOME}/.${SHELL##*/}_profile"
  else
    profile="${HOME}/.bash_profile"
  fi

  if [[ ! -f ${profile} ]]; then
    echo "${profile} does not exist. Creating ${profile}"
    touch ${profile}
    changes_made=1
  fi
  
  echo "Using ${profile} for configurations"
  
  if [[ -n ${PATH} ]]; then
    pyenv_root=$(pyenv root)
    export_string="\$(pyenv root)/shims:"

    if [[ ! "${PATH}" =~ "${pyenv_root}/shims" ]]; then
      echo "Adding export PATH command to ${profile}"
      printf "export PATH=${export_string}\$PATH\n" >> ${profile} 
      changes_made=1
    fi
  fi

  if [[ -z "$(grep 'command -v pyenv' ${profile})" ]]; then
    echo "Adding pyenv snippet to ${profile}"
    printf "if command -v pyenv 1>/dev/null 2>&1; then\n  eval \"\$(pyenv init -)\"\nfi\n" >> ${profile}
    changes_made=1
  fi

  if (( ${changes_made} )); then
    echo "Sourcing ${profile}"
    source ${profile}
  fi
}

function main() {
  #packages=('git' 'pyenv' 'kubectl' 'awscli@2' 'aws-iam-authenticator')
  #python_version='3.9.10'
  #check_brew
  #install_apps
  #install_python
  update_profile
}

main "${0}"
