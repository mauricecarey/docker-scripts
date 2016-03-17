#!/bin/bash

## Check that the given env var is set display error and exit if not.
check_env() {
    if [ -z "${!1}" ]; then
        echo >&2 "Need to set ${1}"
        exit 1
    fi
}

## Check the given env var is assigned if not set to the given default.
check_set_default() {
    eval "${1}=${!1:-$2}"
    [ "$debug" == "on" ] && echo "Using $1:" ${!1}
}

## Main script.

# Set default config (read from the working directory).
DEFAULT_CONFIG=$(pwd)/entrypoint.config
DEFAULT_SETUP=entrypoint-setup.sh

# Parse command line parameters given to the script.
debug=off
entrypoint=
config=
while getopts de:c:s: opt
do
    case "$opt" in
        c)  config="$OPTARG";;
        d)  debug=on;;
        e)  entrypoint="$OPTARG";;
        s)  setup="$OPTARG";;
        \?)   # unknown flag
            echo >&2 \
                "usage: $0 [-v] [-e entrypoint] [parameter ...]"
            exit 1;;
    esac
done
shift `expr $OPTIND - 1`

# Check for default config file (entrypoint.config) if config is not already provided.
if [ -z "${config}" ] && [ -r ${DEFAULT_CONFIG} ]; then
    config=${DEFAULT_CONFIG}
fi

# Read the config file.
# The format for the config file is a number of lines of: VAR=some command
if [ -n "${config}" ]; then
    while read line; do
        export "$line"
    done < ${config}
fi

# Setup the entrypoint.
check_set_default entrypoint ENTRYPOINT_MAIN
check_env ${entrypoint}

# Parse the entrypoint command to single command plus args.
COMMAND=$(echo ${!entrypoint} | tr ' ' "\n" | head -n 1)
ARGS=$(echo ${!entrypoint} | tr ' ' '\n' | tail -n +2 | tr '\n' ' ')

# Run any defined setup script.
if [ -z "${setup}" ] && [ -r ${DEFAULT_SETUP} ]; then
    setup=${DEFAULT_SETUP}
fi
if [ -n "${setup}" ] && [ -x ${setup} ]; then
    base_dir="$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
    (exec ${base_dir}/${setup})
fi

# Print out debug info if active.
if [ "$debug" == "on" ]; then
    if [ -z "${ARGS}" ]; then
        echo "Entrypoint: ${entrypoint}" "Parameters: $@" "Command: ${COMMAND} $@"
    else
        echo "Entrypoint: ${entrypoint}" "Parameters: $@" "Command: ${COMMAND} ${ARGS} $@"
    fi
fi

# Execute the command from the given entrypoint.
exec "${COMMAND}" ${ARGS} $@
