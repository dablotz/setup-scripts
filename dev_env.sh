#! /usr/bin/env bash

set -o errexit
set -o pipefail

profile=""

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
# Existing 
function check_java() {
  java_packages=('openjdk@8' 'openjdk@11')
  javas_to_install=()
  
  if command -v java >/dev/null 2>&1; then
    javas_to_install=('openjdk@8' 'openjdk@11')
  else
    installed_javas=$(/usr/libexec/java_home -V 2>&1)

    if [[ "${installed_javas}" =~ "Java SE 8" ]]; then
      if [[ "${installed_javas}" =~ "Open JDK 8" ]]; then
        echo "Java 8 installed"
      else
        echo "Java 8 not found"
        javas_to_install+='openjdk@8'
      fi
    fi
    
    if [[ "${installed_javas}" =~ "Java SE 11" ]]; then
      if [[ "${installed_javas}" =~ "Open JDK 11" ]]; then
        echo "Java 11 installed"
      else
        echo "Java 11 not found"
        javas_to_install+='openjdk@11'
      fi
    fi
  fi
 
  if (( ${#javas_to_install[@]} > 0 )); then
    # Making sure the AdoptOpenJdk tap is tapped before potentially installing java versions with brew
    brew tap adoptopenjdk/openjdk
    echo "Java binaries not found. Checking brew cellar for - ${javas_to_install[@]}"
    install_apps "${javas_to_install[@]}"
    echo "Adding Java aliases"
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
    return 1 # this might be the wrong way to bail if package_name is not in outdated_list
  fi
}

# Uses pyenv to install python
function install_python() {
  if pyenv versions >/dev/null 2>&1; then
    if [[ -n "$(pyenv versions | grep ${python_version})" ]]; then
      echo "python ${python_version} found. Not installing python ${python_version}"
    else
      pyenv install "${python_version}"
      pyenv global "${python_version}"
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

    if [[ ! ${PATH} =~ "pyenv" ]]; then
      echo "Adding export PATH command to ${profile}"
      printf "export PATH=${export_string}\$PATH\n" >> ${profile} 
      source_profile
    fi
  fi

  # Check if the pyenv snippet already exists in .{shell}_profile
  # Add it to the file if not.
  if [[ -z "$(grep 'command -v pyenv' ${profile})" ]]; then
    echo "Adding pyenv snippet to ${profile}"
    printf "if command -v pyenv 1>/dev/null 2>&1; then\n  eval \"\$(pyenv init -)\"\nfi\n" >> ${profile}
    source_profile
  fi  
}

# Adds java alias to user's .{shell}_profile file
function add_java_alias() {
  javas=("$@")
  
  if [[ ${javas[@]} =~ "8" ]]; then
    echo "Creating symlink for openjdk@8"
    sudo ln -sfn /usr/local/opt/openjdk@8/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-8.jdk
    printf "export JAVA_8_HOME=\$(/usr/libexec/java_home -v1.8)\nalias java8='export JAVA_HOME=\$JAVA_8_HOME'\n" >> ${profile}
    source_profile
  fi
  if [[ ${javas[@]} =~ "11" ]]; then
    sudo ln -sfn /usr/local/opt/openjdk@11/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-11.jdk
    printf "export JAVA_11_HOME=\$(/usr/libexec/java_home -v11)\nalias java11='export JAVA_HOME=\$JAVA_11_HOME'\n" >> ${profile}
    source_profile
  fi
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
    source_profile
  fi
}

# Source user's dot profile file
function source_profile() {
  echo "Sourcing ${profile}"
  source ${profile}
}

function main() {
  # Command line (console) packages to install with homebrew
  console_packages=('git' 'pyenv' 'maven@3.5')
  
  # Python version string - (optional) leave blank to skip install of python
  python_version='3.9.10'
  
  # Determine the .{shell}_profile file to use for configuration (.bash_profile, .zsh_profile, etc.)
  get_user_shell_profle
  
  # Check on brew - install if necessary
  check_brew

  # Check installed Java versions for jdk 8 and jdk 11. Install either if not found
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
}

main "${0}"
