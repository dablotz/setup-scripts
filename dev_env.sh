#! /usr/bin/env bash

set -o errexit
set -o pipefail

profile=""
changes_made=0

# Check if homebrew (brew) is installed
# If yes update brew, otherwise install from the internet
function check_brew() {
  if check_command "brew"; then
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

# Check if Java 8 and Java 11 are installed and on path
function check_java() {
  # If both are found, assume aliases exist??
  # can't be sure associative arrays are available so these two arrays need to match
  java_versions=('Java SE 8' 'Java SE 11')
  java_packages=('openjdk8' 'openjdk11')
  
  installed_javas=$(/usr/libexec/java_home -V 2>&1)
  javas_to_install=()

  for idx in "${!java_versions[@]}"; do
    if [[ "${installed_javas}" =~ "${java_versions[${idx}]}" ]]; then
      echo "${java_versions[${idx}]} installed"
    else
      echo "${java_versions[${idx}]} not found"
      javas_to_install+="${java_packages[${idx}]}"
    fi
  done

  if (( ${#javas_to_install[@]} > 0 )); then
    echo "Java packages to be installed - ${javas_to_install[@]}"
    install_apps "${javas_to_install[@]}"
    add_java_alias "${javas_to_install[@]}"
  else
    echo "No Java versions will be installed"
  fi
}

# Uses homebrew to install command line apps
function install_apps() {
  to_be_installed=("$@")

  # Loop over array of packages to see if they are installed and up to date
  # Install or update packages as needed
  for package in "${to_be_installed[@]}"; do
    if brew list ${package} >/dev/null 2>&1; then
      echo "Brew has already installed ${package}. Checking that ${package} is up to date."
      if is_outdated "${package}"; then
        brew upgrade ${package}
      else
        echo "${package} is up to date."
      fi
    else
      echo "Brew cannot find ${package}. Installing ${package}"
      brew install ${package}
    fi
  done
}

# Checks if the supplied package is in the list of outdated brew formulae and casks
function is_outdated() {
  package_name=$@
  outdated_list=$(brew outdated)

  if [[ ! "${outdated_list}" =~ "${package_name}" ]]; then
    return 1
  fi
}

# Uses pyenv to install python
function install_python() {
  if pyenv versions >/dev/null 2>&1; then
    if [[ -n "$(pyenv versions | grep ${python_version})" ]]; then
      echo "python ${python_version} found. Not installing python ${python_version}"
    else
      pyenv install "${python_version}"
    fi
  else
    echo "pyenv unavailable"
  fi
}

# Updates the user's shell profile file to include pyenv
function add_pyenv_to_path() {
  # Check if the pyenv root exists in the PATH environment variable.
  # If it does not then add an export PATH command to .{shell}_profile
  if [[ -n ${PATH} ]]; then
    pyenv_root=$(pyenv root)
    export_string="\$(pyenv root)/shims:"

    if [[ ! "${PATH}" =~ "${pyenv_root}/shims" ]]; then
      echo "Adding export PATH command to ${profile}"
      printf "export PATH=${export_string}\$PATH\n" >> ${profile} 
      changes_made=1
    fi
  fi

  # Check if the pyenv snippet already exists in .{shell}_profile
  # Add it to the file if not.
  if [[ -z "$(grep 'command -v pyenv' ${profile})" ]]; then
    echo "Adding pyenv snippet to ${profile}"
    printf "if command -v pyenv 1>/dev/null 2>&1; then\n  eval \"\$(pyenv init -)\"\nfi\n" >> ${profile}
    changes_made=1
  fi  
}

# Adds java alias to user's .{shell}_profile file
function add_java_alias() {
  #do the thing

}

# Check if a command exists
function check_command() {
  command -v $* >/dev/null 2>&1
}

# Determine the dot file to use for adding aliases and export PATH commands
function get_user_shell_profle() {
  # Check for the SHELL environment variable. This is the user's default shell
  # If SHELL is populated use that to set the .{shell}_profile file to use below
  # If SHELL is empty use .bash_profile
  if [[ -n ${SHELL} ]]; then
    profile="${HOME}/.${SHELL##*/}_profile"
  else
    profile="${HOME}/.bash_profile"
  fi

  # Check if .{shell}_profile exists. Create it if not.
  if [[ ! -f ${profile} ]]; then
    echo "${profile} does not exist. Creating ${profile}"
    touch ${profile}
    changes_made=1
  fi
}

# Source user's dot profile file
function source_profile() {
  echo "Sourcing ${profile}"
  source ${profile}
  changes_made=0
}

function main() {
  # Command line (console) packages to install with homebrew
  console_packages=('git' 'pyenv')
  
  # Python version string - (optional) leave blank to skip install of python
  python_version='3.9.10'
  
  # Check on brew - install if necessary
  check_brew

  # Check installed Java versions - automation requires both 8 (auto-framework) and 11 (dnp-auto-framework)
  check_java
  
  # Install the packages in the console_packages array
  install_apps "${console_packages[@]}"
  
  # Supplying a python version is optional. Skip install_python if string is empty
  if [[ -n ${python_version} ]]; then
    install_python
  fi
  
  # If the console_packages array included pyenv check if it needs to be added to the user's PATH
  if [[ "${console_packages[*]}" =~ "pyenv" ]]; then
    add_pyenv_to_path
  fi

  # If the user's .{shell}_profile was altered in any way then source the file
  if (( ${changes_made} )); then
    source_profile
  fi
}

main "${0}"
