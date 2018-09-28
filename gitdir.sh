#!/usr/bin/env bash
#
# Created By: stephansarver
# Created Date: 20180531-092037
#
set -o errexit
set -o errtrace
set -o nounset

clear

#Initialize the command switches
cmd_switch_check_uncommitted="-c"
cmd_switch_delete_config="-d"
cmd_switch_git_fetch="-f"
cmd_switch_show_repo_list="-l"
cmd_switch_git_pull="-p"
cmd_switch_update_repo_list="-u"

github_user=""
github_org_name=""
github_api_base="https://api.github.com"
github_repo_base="https://github.com/"

file_name_for_config=".gitdir_conf"
file_name_for_repos=".gitdir_repos"

#repos=()

function usage(){
  echo "USAGE:"
  echo " "
  echo "  Name: gitdir"
  echo " "
  echo "  Description: "
  echo "      This script is used to handle some basic batch git functions for a organizations git repositories."
  echo "      The script will store in hidden files the github organization name and github user name so it does"
  echo "      not have to be re-entered each time the script is run. This script will also store in a hidden file "
  echo "      a list of repos that were looked up for the organization that the user has access to."
  echo "      See additional notes below."
  echo " "
  echo " "
  echo "  Command Switches:"
  echo "      -c Used to check for repos with uncommitted files."
  echo "      -d Used to delete locally stored configuration and start new."
  echo "      -f Used to fetch and update the local git indexes for the repositories."
  echo "      -l Used to show the list of cloned repositories."
  echo "      -p Used to pull the latested currently checked out versions of the repositories."
  echo "      -u Used for updating the locally cached repository list."
  echo " "
}

function throw_error(){
  local_param_property=$1
  local_param_message=$2

  echo "********************"
  echo "Error: "
  echo " "
  echo "  $local_param_property $local_param_message "
  echo " "
  echo "********************"
  exit 1
}

function populate_repo_list {
  touch "$file_name_for_repos"
  curl --user "$github_user" "$github_api_base/orgs/$github_org_name/repos?per_page=100" | jq -r ".[].name" >"$file_name_for_repos"
}

function delete_git_config {
  echo "You are about to delete your saved github organization name and github user name you will have to re-enter this the next time you run this script are you sure you want to proceed?"
  read -r delete_config
  if [[ "y" == "$delete_config" || "Y" == "$delete_config" || "yes" == "$delete_config" || "YES" == "$delete_config" || "Yes" == "$delete_config" ]]; then
    if [ -f "$file_name_for_config" ]; then
      rm "$file_name_for_config"
    else
      echo "The config file does not exist and could not be deleted: $file_name_for_config"
    fi
  else
    throw_error "Aborted deleteing gitdir config." "$delete_config"
  fi
}

function load_git_config {
  if [ ! -f "$file_name_for_config" ]; then
    echo "Creating git config file"
    create_git_config
  fi

  if [ -f "$file_name_for_config" ]; then
    echo "loading from git config file"
    gitdir_config=$(cat $file_name_for_config)
    echo "$gitdir_config"

    #declare -a gitdir_configs=(${gitdir_config//|/ })

    OLDIFS=$IFS
    IFS='|' read -r -a gitdir_configs <<< "$gitdir_config"
    IFS=$OLDIFS

    github_org_name="${gitdir_configs[0]}"
    github_user="${gitdir_configs[1]}"
  fi

  if [[ "" == "$github_user"  || "" == "$github_org_name" ]]; then
    echo "Storing to git config file"
    create_git_config
  fi
}

function create_git_config {
  echo " "
  echo "Please enter the github organization name and hit enter:"
  read -r github_org_name
  echo " "
  echo "Please enter your github user name and hit enter:"
  read -r github_user
  echo "You have entered the following values:"
  echo "  github organization: $github_org_name"
  echo "  github user: $github_user"
  echo " "
  echo "Are these correct?"
  read -r correct_entries
  if [[ "y" == "$correct_entries" || "Y" == "$correct_entries" || "yes" == "$correct_entries" || "YES" == "$correct_entries" || "Yes" == "$correct_entries" ]]; then
    touch "$file_name_for_config"
    echo "$github_org_name|$github_user">"$file_name_for_config"
  else
    throw_error "Aborting saving github organization and username."
  fi
}

function pull_repos {
  fetch_repos "y"
}

function fetch_repos {
  pull_current_branch="$1"
  while read -r repo; do
    message="Repo: $repo"
    repo_cloned="false"
    for directory in *
    do
      if [[ -d $directory ]]; then
        if [[ "$directory" == "$repo" ]]; then
          message="$message - Found - fetching from git"
          if [[ "y" == "$pull_current_branch" ]]; then
            message="$message - pulling latest into current branch."
          fi
          pushd . > /dev/null 2>&1
          cd "$repo" > /dev/null 2>&1
          echo "$message"
          git fetch --all
          if [[ "y" == "$pull_current_branch" ]]; then
            trap "git pull" EXIT
          fi
          repo_cloned="true"
          popd > /dev/null 2>&1
        fi
      fi
    done
    if [[ "false" == "$repo_cloned" ]]; then
      echo "$message not found, cloning!"
      git clone "$github_repo_base$github_org_name/$repo.git"
    fi
    echo " "
  done <"$file_name_for_repos"
}

function check_for_uncommitted {
  no_local_changes_found="true"
  while read -r repo; do
    for directory in *
    do
      if [[ -d $directory ]]; then
        if [[ "$directory" == "$repo" ]]; then
          pushd . > /dev/null 2>&1
          cd "$repo" > /dev/null 2>&1
          status="$(git status)"
          if [[ "$status" == *"Changes not staged for commit"* || "$status" == *"Untracked files"* ]]; then
            echo " "
            echo " "
            echo "--------------------------------------"
            echo "$repo : Local changes found!"
            echo "--------------------------------------"
            echo "$status"
            no_local_changes_found="false"
          fi
          popd > /dev/null 2>&1
        fi
      fi
    done

  done <"$file_name_for_repos"
  if [ "true" == "$no_local_changes_found" ]; then
    echo " "
    echo "No changes found!"
    echo " "
  fi

}

function show_repo_list {
    cat "$file_name_for_repos"
}


#Start processing by checking for command switches if there are none print usage and exit.
if [[ "" == "$*" ]]; then
  usage
  exit 1
fi

for arg in "$@"
do
  if [[ "$arg" == "$cmd_switch_check_uncommitted" ]]; then
    echo "---- Checking repos for uncommitted files ----"
    check_for_uncommitted
  elif [[ "$arg" == "$cmd_switch_delete_config" ]]; then
    echo "---- Deleting gitdir config! ---- "
    delete_git_config
  elif [[ "$arg" == "$cmd_switch_git_fetch" ]]; then
    echo "---- Executing gitdir fetch! ---- "
    load_git_config
    populate_repo_list
    fetch_repos "n"
  elif [[ "$arg" == "$cmd_switch_show_repo_list" ]]; then
    echo "---- Show gitdir repo list! ---- "
    show_repo_list
  elif [[ "$arg" == "$cmd_switch_git_pull" ]]; then
    echo "---- Executing gitdir pull! ---- "
    load_git_config
    populate_repo_list
    pull_repos
  elif [[ "$arg" == "$cmd_switch_update_repo_list" ]]; then
    echo "---- Executing gitdir update repo list! ---- "
    load_git_config
    populate_repo_list
  else
    usage
    throw_error "Unexpected parameter found:" "$arg"
  fi
done

echo " "
echo "_______________________________"
echo "Completed: $(date +%Y.%m.%d-%H:%M:%S)"
echo " "
