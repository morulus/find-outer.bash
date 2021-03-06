#!/bin/bash
# resolve-up - A shortest way to find up a path in the parent directories
# https://github.com/morulus/resolve-up.bash
#
# @version 0.1.4
# @author Vladimir Kalmykov <vladimirmorulus@gmail.com>
# @license MIT

PROGRAM=$(realpath "$0")
PROGRAM_NAME="resolve-up"
COLOR='\033[1;33m'
NC='\033[0m'
COLORED_PROGRAM="$(echo -e "${COLOR}$PROGRAM_NAME${NC}")"

# Default arguments
LIMIT=99999
MODIFIER=""
RESOLVER=""
GREEDY=0

# Handle arguments
POSITIONAL=()
ARGUMENTS=""
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -n|--limit)
    LIMIT=$(($2 + 0))
    shift # past argument
    shift # past value
    ;;
    -g|--greedy)
    GREEDY=1
    shift # past argument
    ;;
    -m|--modif)
    MODIFIER="$2"
    ARGUMENTS="$ARGUMENTS $1 $2"
    shift # past argument
    shift # past value
    ;;
    -r|--resolver)
    RESOLVER="$2"
    ARGUMENTS="$ARGUMENTS $1 $2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

colored() {
  echo -e "${COLOR}$1${NC}"
}

cmd_usage() {
  cat <<_EOF

    $COLORED_PROGRAM $(colored "[...params] [pattern]")

    Resolve path in parent directories

    Params:

    $COLORED_PROGRAM $(colored "-n [limit]") Limit output count
    $COLORED_PROGRAM $(colored "-g") Greedy mode (dont stop search on match)

_EOF
}

modify() {
  local result=$1
  if [ -n "$MODIFIER" ]; then
    if ! result=$($MODIFIER "$result"); then
      # Ignore error and just skip errored value
      exit 0
    fi
  fi
  echo "$result"
}

buildinResolve() {
  local result=$1
  local nextResult
  if [ -n "$RESOLVER" ]; then
    if nextResult=$($RESOLVER "$result"); then
      echo "$nextResult"
      return 0
    fi
  fi

  if [ -f "$result" ] || [ -d "$result" ]; then
    echo "$result"
    return 0
  fi
  return 1
}

resolve() {
  local query="$1"
  local absPath
  local resolvedPath
  local postResult
  if [[ $1 =~ .*\*.* ]] && [[ $(pwd) != '/' ]]; then
    cd "$(dirname "$(pwd)")" || return 1
    local result=""
    if [[ $(pwd) != '/' ]]; then
      # shellcheck disable=SC2086
      if ! result=$($PROGRAM $query $ARGUMENTS); then
        return 1
      else
        echo "$result"
      fi
    else
      return 1
    fi
  else
    if [ $# == 0 ]; then
      return 1;
    fi
    if [ $# == 1 ]; then
      if resolvedPath=$(buildinResolve "$1"); then
        absPath="$(realpath "$resolvedPath")"
        postResult="$absPath"
        if postResult=$(modify "$absPath"); then
          echo "$postResult"
        else
          echo ""
        fi
        exit 0
      fi

      # Search in parent directories
      cd "$(dirname "$(pwd)")" || return 1
      local result=""
      if [[ $(pwd) != '/' ]]; then
        # shellcheck disable=SC2086
        if ! result=$($PROGRAM $query $ARGUMENTS); then
          return 1
        else
          echo "$result"
        fi
      else
        return 1
      fi
    else
      local index=0
      # Handle resolved by OS/user list of files
      for var in "$@"
      do
        if [ $index -eq "$LIMIT" ]; then
          exit 0
        fi
        ((index++))

        # Post resolve with modifier
        absPath="$(realpath "$var")"
        postResult="$absPath"
        if postResult=$(modify "$absPath") && [ -f "$absPath" ] || [ -d "$absPath" ]; then
          echo "$postResult"
        fi
      done
      exit 0
    fi
  fi
}

strindex() {
  x="${1%%$2*}"
  [[ "$x" = "$1" ]] && echo -1 || echo "${#x}"
}

cmd_resolve() {
  local query
  local superpos
  if [ $GREEDY -eq 1 ] && (( "$#" == 1 )) && [ "${1:0:1}" = "/" ]; then
    # Disable greedy
    GREEDY=0
  fi
  if [ $GREEDY -eq 1 ] && (( "$#" > 1 )); then
    echo "Greedy mode doesn't work with glob patterns and multiple files"
    echo "Remove flag -g and go on"
    exit 1
  fi
  local result=""
  if ! result=$(resolve "$@"); then
    echo "$PROGRAM_NAME: $1 not found"
    exit 1
  else
    # shellcheck disable=SC2206
    local lines=(${result[@]})
    local count="${#lines[@]}"
    if ((count > LIMIT)); then
      # Slice excess values
      lines=("${lines[@]:0:$LIMIT}")
      result=$(printf "%s\n" "${lines[@]}")
    fi
    echo "$result"
    if ((count < LIMIT)) && [ $GREEDY -eq 1 ]; then
      query="${result[0]}"
      superpos=${query//"$1"/""}
      # shellcheck disable=SC2086
      if result=$(cd $superpos && cd .. && $PROGRAM $1 $ARGUMENTS -g); then
        echo "$result"
      fi
    fi
    exit 0
  fi
}

case "$1" in
    --help|-h) shift;               cmd_usage "$@" ;;
    *)                             cmd_resolve "$@" || exit 1 ;;
esac
