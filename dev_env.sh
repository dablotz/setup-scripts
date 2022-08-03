#! /usr/bin/env bash -i

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

# Check if Java 8 and Java 11 are installed
# Pass uninstalled versions to install_apps to be installed with brew
function check_java() {
  javas_to_install=()
  
  if ! check_command "java"; then
    javas_to_install=('openjdk@8' 'openjdk@11')
  else
    installed_javas=$(/usr/libexec/java_home -V 2>&1)
    echo ${installed_javas[@]}

    # These checks could be teased out into a function
    # from here
    if [[ "${installed_javas}" =~ "Java SE 8" || "${installed_javas}" =~ 'openjdk@8' ]]; then
      echo "Java 8 installed"
    else
      echo "Java 8 not found"
      javas_to_install+='openjdk@8'
    fi
    
    if [[ "${installed_javas}" =~ "Java SE 11" || "${installed_javas}" =~ "openjdk@11" ]]; then
      echo "Java 11 installed"
    else
      echo "Java 11 not found"
      javas_to_install+='openjdk@11'
    fi
    # to here
  fi
 
  if (( ${#javas_to_install[@]} > 0 )); then
    echo "Java binaries not found. Using brew to install - ${javas_to_install[@]}"
    install_apps "${javas_to_install[@]}"
    echo "Adding Java aliases"
    add_java_alias "${javas_to_install[@]}"
  else
    echo "No Java versions will be installed"
  fi
}

# Downloads the aws-cli binary from amazon and installs it.
function check_aws() {
  if ! check_command 'aws --version'; then
    echo "aws-cli not found. Downloading aws-cli from https://awscli.amazonaws.com"
    if ! curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"; then
      echo "Unable to download aws-cli"
    else
      echo "Installing downloaded package for aws-cli"
      sudo installer -pkg AWSCLIV2.pkg -target /
    fi
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

# Checks if the supplied package is in the list of outdated brew formulae and casks
function is_outdated() {
  package_name=$@
  outdated_list=$(brew outdated)

  if [[ ! "${outdated_list}" =~ "${package_name}" ]]; then
    return 1 # this might be the wrong way to bail if package_name is not in outdated_list
  fi
}

# Updates the user's shell profile file to include pyenv
function add_pyenv_to_path() {
  # Check if the pyenv root exists in the PATH environment variable.
  # If it does not then add an export PATH command to ${profile}
  if [[ -n ${PATH} ]]; then
    pyenv_root=$(pyenv root)
    export_string="\$(pyenv root)/shims:"

    if [[ ! ${PATH} =~ "pyenv" ]]; then
      echo "Adding export PATH command to ${profile}"
      printf "export PATH=${export_string}\$PATH\n" >> ${profile}
    fi
  fi

  # Check if the pyenv snippet already exists in ${profile}
  # Add it to the file if not.
  if [[ -z "$(grep 'command -v pyenv' ${profile})" ]]; then
    echo "Adding pyenv snippet to ${profile}"
    printf "if command -v pyenv 1>/dev/null 2>&1; then\n  eval \"\$(pyenv init -)\"\nfi\n" >> ${profile}
  fi  
}

# Adds java alias to ${profile}
function add_java_alias() {
  javas=("$@")
  
  if [[ ${SHELL} =~ "zsh" ]]; then
    source "${HOME}/.zprofile"
  fi
  shopt -s expand_aliases

  if [[ ${javas[@]} =~ "8" ]]; then
    # Creating symlink for openjdk@8
    sudo ln -sfn /usr/local/opt/openjdk@8/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-8.jdk
    
    if ! check_command "java8"; then
      echo "Creating alias for java8"
      printf "alias java8='export JAVA_HOME=$(/usr/libexec/java_home -v 1.8.0)'\n" >> ${profile}
    fi
  fi
  if [[ ${javas[@]} =~ "11" ]]; then
    # Creating symlink for openjdk@11
    sudo ln -sfn /usr/local/opt/openjdk@11/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-11.jdk
    
    if ! check_command "java11"; then
      echo "Creating alias for java11"
      printf "alias java11='export JAVA_HOME=$(/usr/libexec/java_home -v 11)'\n" >> ${profile}
    fi
  fi
}

# Check if a command exists
function check_command() {
  command -v $* >/dev/null 2>&1
}

# Determine the dot file to use for adding aliases and export PATH commands
function get_user_shell_profle() {
  # Check for the SHELL environment variable. This is the user's default shell
  # If SHELL is populated use that to set the dot file to use below
  # If SHELL is empty use .bash_profile
  if [[ -n ${SHELL} && ${SHELL} =~ "zsh" ]]; then
    profile="${HOME}/.zprofile"
  else
    profile="${HOME}/.bash_profile"
  fi

  # Check if ${profile} exists. Create it if not.
  if [[ ! -f ${profile} ]]; then
    echo "${profile} does not exist. Creating ${profile}"
    touch ${profile}
  fi
}

function main() {
  # Command line packages to install with homebrew
  console_packages=('git' 'pyenv' 'maven@3.5' 'aws-iam-authenticator' 'kubectl')
  
  # Gui packages
  cask_packages=('--cask intellij-idea' '--cask insomnia')

  # Python version string
  python_version='3.9.13'
  
  # Determine the .{shell}_profile file to use for configuration (.bash_profile, .zprofile, etc.)
  get_user_shell_profle
  
  # Check on brew - install if necessary
  check_brew

  # Check installed Java versions for jdk 8 and jdk 11. Install either if not found
  check_java

  # Check for aws-cli and install if needed
  check_aws

  # Install the packages in the console_packages array
  install_apps "${console_packages[@]}"

  # Install the gui packages (casks)
  install_apps "${cask_packages[@]}"
  
  # Use pyenv to install $python_version
  install_python  
  
  # Make sure the shims directory for pyenv gets into the user's $PATH
  add_pyenv_to_path
  
  # Print out any manual steps that need to happen.
  printf "Commands to be run manually:\n    source ${profile}\n    pyenv global ${python_version}\n"
}

main "${0}"
