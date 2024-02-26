#!/usr/bin/env bash

# Release script
# 
# A script that will help our CI to run a bulk action in release time after deployments. And it has a some flags that are required to run this script.
# 
# usage: ./scripts/release [--type] [--type] [--path]
# example: ./scripts/release --type=minor --workplace=apps --path=server/api
# 
# These are common release commands used for releasing:
# 
# type                Specifying what kind of version types (major, minor or patch) would you like to use in releasing packages/apps.
# workspace           Apps or packages which one of them would you like to release?
# path                A directory path where the package.json placed.
# 
# The command will run a couple of tasks and produce a git tag like "@github/firebase-1.1.0" 
# Then push that tag to the Github repository.

set -euo pipefail

workspaceName=""
pkgJson=""
latestVersion=""
tagVersion=""
tagMessage=""

declare -A commands=(
  [type]="" 
  [workspace]=""
  [path]=""
)

updateVersion() {
  echo "${pkgJson}"
  sed -i "s/\"version\": \".*\"/\"version\": \"$latestVersion\"/" ${pkgJson}
}

createTagMessage() {
  tagMessage="
[Release] Bump version to ${tagVersion} (${PULL_REQUEST_URL}). 
Change was created by the github actions and automation script.
  "
}

createGitTag() {
  dirPath="${commands[workspace]}/${commands[path]}"
  tagVersion="${workspaceName}-${latestVersion}"

  createTagMessage

  echo "Create tag on ${workspaceName} workspace."
  
  git fetch
  git add ${dirPath}
  git commit -m "chore: release ${tagVersion}"

  if [ -z "${COMMIT_TAG}" ]; then
    git tag ${tagVersion} ${COMMIT_TAG} -m "${tagMessage}"
  else
    git tag ${tagVersion} -m "${tagMessage}"
  fi


  # Push tag to remote repository
  git push origin ${tagVersion}

  # Push commit to remote branch
  git push origin main
}

genereteVersion() {
  pkgJson="${commands[workspace]}/${commands[path]}/package.json"
  latestVersion=$(jq -r .version ${pkgJson})
  workspaceName=$(jq -r .name ${pkgJson})

  if [ -z "$latestVersion" ]; then
    latestVersion="0.0.0"
  fi

  if [ "${commands[type]}" = "patch" ]; then
    latestVersion="$(echo "$latestVersion" | awk -F. '{$NF++; print $1"."$2"."$NF}')"
  elif [ "${commands[type]}" = "minor" ]; then
    latestVersion="$(echo "$latestVersion" | awk -F. '{$2++; $3=0; print $1"."$2"."$3}')"
  elif [ "${commands[type]}" = "major" ]; then
    latestVersion="$(echo "$latestVersion" | awk -F. '{$1++; $2=0; $3=0; print $1"."$2"."$3}')"
  else
    printf "\nError: invalid VERSION_TYPE arg passed, must be 'patch', 'minor' or 'major'\n\n"
    exit 1
  fi

  echo "Successfully generated the latest version of ${workspaceName} to => ${latestVersion}"
}

populateArguments() {
  for cmd in "$@";
  do
    IFS=-= read -a formattedValue <<< "${cmd//, ,}"
    declare -p formattedValue

    type="${formattedValue[2]}"
    value="${formattedValue[3]}"

    commands[${type}]=${value}
  done
}

run() {
  echo "Running release tasks..."

  populateArguments "$@"
  genereteVersion
  updateVersion

  # Execute git commands
  createGitTag
}

run "$@"