#!/bin/bash

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
    if pyenv versions | grep ${python_version}; then
      echo "python ${python_version} found. Not installing python ${python_version}"     
    else
      pyenv install "${python_version}"
    fi    
  else
    echo "pyenv unavailable"
  fi
}

# Updates the users shell profile file to include pyenv 
function update_profile() {
  profile=""
  changes_made=0
  
  if [ -n ${SHELL} ]; then
    profile="${HOME}/.${SHELL:(-3):3}_profile"
  else
    profile="${HOME}/.bash_profile"

  if [ ! -f ${profile} ]; then
    echo "${profile} does not exist. Creating ${profile}"
    touch ${profile}
    changes_made=1
  fi

  export_string="\$(pyenv root)/shims:"

  if [ -z "$(grep 'export PATH' ${profile})" ]; then
    echo "Adding export PATH command to ${profile}"
    printf "export PATH=${export_string}:\$PATH\n" >> ${profile}
    changes_made=1
  else
    if [ -z "$(grep 'pyenv root' ${profile})" ]; then
      echo "Adding ${export_string} to ${profile}"
      sed -i.bak "s?PATH=?&${export_string}?" ${profile}
      changes_made=1
    else
      echo "export PATH command contains pyenv shims"
    fi
  fi

  if [ -z "$(grep 'command -v pyenv' ${profile})" ]; then
    echo "Adding pyenv snippet to ${profile}"
    printf "if command -v pyenv 1>/dev/null 2>&1; then\n  eval \"\$(pyenv init -)\"\nfi\n" >> ${profile}
    changes_made=1
  fi

  if changes_made; then
    echo "Sourcing ${profile}"
    source ${profile}
  fi
}

function main() {
  packages=('git' 'pyenv' 'kubectl' 'awscli@2' 'aws-iam-authenticator')
  python_version='3.9.10'
  check_brew
  install_apps
  install_python
  update_profile
}

main "${0}"