#!/usr/bin/env bash
#
# Welcome to the MoonShell initialiser
#
# Sourcing this file sources all files in lib/ and etc/ and prepends bin/ to
# PATH.
#
# Custom libraries can be created in lib/private/ and custom variables defined
# in etc/profile.d/private/; these locations are auto-sourced, but .gitignore'd
#
# Copyright: Phil Ingram (pingramdotau@gmaildotcom)
#

[[ ${DEBUG-} == true ]] && set -x


#
# GLOBAL VARIABLES
#
[[ -z ${MOON_ROOT-} ]] \
    && export MOON_ROOT="$(dirname ${BASH_SOURCE[0]})"
# realpath resolves symlinks which can be handy
export MOON_ROOT_REALPATH="$(realpath ${MOON_ROOT})"

export MOON_SHELL="${MOON_ROOT}/moon.sh"

export MOON_BIN="${MOON_ROOT}/bin"
export MOON_ETC="${MOON_ROOT}/etc"
export MOON_LIB="${MOON_ROOT}/lib"
export MOON_USR="${MOON_ROOT}/usr"

# Not all users on a system can write to their ${HOME}
if [[ -w ${HOME} ]]; then
    export MOON_HOME="${HOME}/.moonshell"
    [[ ! -d ${MOON_HOME} ]] && mkdir -m 0700 -p ${MOON_HOME}
else
    export MOON_HOME="${MOON_ROOT}"
fi

# MOON_VAR is used for persisting of ephemeral data such as state, completion
# scripts, log and application output. It is primarily used by console users,
# does not need to be writable by service users, but must be set and exist.
export MOON_VAR="${MOON_HOME}/var"
if [[ -w ${MOON_HOME} ]] && [[ ! -d ${MOON_VAR} ]]; then
    mkdir ${MOON_VAR}
fi

export MOON_COMPLETION="${MOON_ETC}/completion.d"
export MOON_PROFILE="${MOON_ETC}/profile.d"

export MOON_FIND_OPTS="-mindepth 1 -maxdepth 1"


#
# SELF CHECK
#
# This enables moon.sh to be sourced, and if not 'installed' will work through
# creating symlinks, updating .bashrc/.bash_profile and installing gems
#
if [[ ${MOON_ROOT} =~ " " ]]; then
    echo "ERROR: The path to moon.sh can not contain spaces: '${MOON_ROOT}'" 1>&2
    return 1
fi

source ${MOON_LIB}/common.sh
source ${MOON_LIB}/moonshell.sh
source ${MOON_LIB}/overlay.sh


#
# PROFILES
#
# As with files in /etc/profile.d, profile files in Moonshell should be used to
# define variables and other less dynamic things. Functions should not reside
# here, but if they do, they must work outside of a moonshell initialised
# environment. Handy things to define in etc/profile.d/private:
#   * AWS_ACCOUNTS[@]
#   * AWS_REGION
_moonshell_source ${MOON_PROFILE}


#
# COMPLETE
#
# Bash has great functionality, via simple functions, to make options to
# scripts and functions tab completable; which aids productivity and ease of
# use.
_moonshell_source ${MOON_COMPLETION}

#
# PATH MODIFICATION
#
[[ -z ${MOON_PATH_PRE-} ]] && export MOON_PATH_PRE="${PATH}"
overlay_path_prepend ${MOON_BIN}


#
# SCRIPT INITIALISATION
#
# When we have been sourced by a script $(basename $0) will be the name of the
# parent script, not bash. If a person has made a script called "bash"... Well,
# it would be irresponsible for us to make a work around for their gross and
# negligent incompetence.
if [[ ! $(basename "x$0") =~ "bash"$ ]]; then
    # Now that we are not running in a shell treat all undefined variables and
    # non-zero exit codes as serious and exit.
    set -eu

    # We require a way of differentiating accounts and bastion hosts , so we
    # set AWS_ACCOUNT_NAME. This variable is not used by any AWS tools, so
    # we appropriate it here. We make the assumption that your bastion hosts,
    # as defined in ~/.ssh/config, follow the naming convention of
    # "bastion-${AWS_ACCOUNT_NAME}"
    [[ -z ${AWS_ACCOUNT_NAME-} ]] \
        && echoerr "ERROR: Unset variable: AWS_ACCOUNT_NAME" \
        && exit 1

    # AWS_REGION is required by the majority of AWS cli commands, so we should
    # set a default.
    [[ -z ${AWS_REGION-} ]] \
        && export AWS_REGION="ap-southeast-2"

    # Most scripts in bin/ build off of ${APP_NAME} which is programatically
    # set below. For those that don't need APP_NAME, i.e. can be run from
    # anywhere in the filesystem, they can export ${MOON_FILE} as false and
    # bypass this failure mode.
    #
    # We only support an APP_NAME which does not contain hyphens. We make
    # this assumption to simplify code and deliberately choose one side of
    # the fence; Mea culpa.
    if [[ ${MOON_FILE-} == false ]]; then
        # Nothing to see here
        true
    elif [[ -f ${PWD}/moonshell/moonshell.sh ]]; then
        source ${PWD}/moonshell/moonshell.sh

        if [[ -z ${APP_NAME-} ]]; then
            echoerr "FATAL: Unset variable: APP_NAME"
            exit 255
        elif [[ ! ${APP_NAME} =~ ^[a-z0-9A-Z_]*$ ]]; then
            echoerr "ERROR: APP_NAME may only contain alpha-numeric characters and underscores"
            exit 1
        fi
    else
        echoerr "ERROR: Can not find: moonshell/moonshell.sh"
        exit 1
    fi

    # Source the rest of the things!!!
    _moonshell_source ${MOON_LIB}
    _moonshell_source ${MOON_COMPLETION}

    # Auto-source the CWD, unless we are in /
    # /etc/profile.d/*.sh can not be sourced with `set -u`
    [[ ! $(realpath ${PWD}) =~ ^/$ ]] \
        && overlay_dir ${PWD} \
        || true
fi

