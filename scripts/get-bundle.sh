#! /bin/bash
# get-bundle [FETCH] [DIR]

## spell-checker:ignore (shell-commands) chmod eval mkdir openssl readlink shellcheck xargs
## spell-checker:ignore BUNDIR devops toplevel unbundle

set -e ## '-e' == exit if pipeline fails

export FETCH="${1:-${FETCH}}" ; FETCH="${FETCH:-https://cdn.statically.io/gh/CICD-tools/devops.wass/master/devops.git.bundle.ssl?env=dev}"
export DIR="${2:-${DIR}}" ; DIR="${DIR:-${HOME}/.secrets.devops}"

DIR=$(mkdir -p -- "${DIR}" ; cd -- "${DIR}" || { echo "ERR!: unable to \`cd -- \"${DIR}\"\`" 1>&2 ; exit 1 ; } ; pwd)

# echo "FETCH=${FETCH}"
# echo "DIR=${DIR}"

# require `git`
which git >/dev/null || { sudo apt-get -y install git </dev/null || { echo "ERR!: unable to install \`git\`" >&2 ; exit -1; } }

# shellcheck disable=SC2016
{
# setup `git` bundle aliases
# :: * `git bundle-config [VAR [VALUE]]` # VAR == a valid POSIX shell variable name ; VALUE == optional configuration value to be saved (defaults to current value of shell VAR); with no arguments, prints current configuration
git config --global alias.bundle-config '!f() { ROOT="$(git rev-parse --show-toplevel)" || { echo "git repository error" 1>&2 ; exit 1 ; } ; BUNDIR="${ROOT}/.git/bundle" ; if [ ! -d "${BUNDIR}" ] ; then mkdir -p "${BUNDIR}" ; chmod -R go-rwx "${BUNDIR}" ; fi ; KFILE="${BUNDIR}/git.bundle.env" ; if [ ! -e "${KFILE}" ] ; then touch "${KFILE}" ; chmod go-rwx "${KFILE}" ; fi ; VAR="$1" ; [ -n "${VAR}" ] || { cat "${KFILE}" ; exit 0 ; } ; VALUE="${2}" ; [ -z "${VALUE}" ] && eval "VALUE=\$${VAR}" ; LINES="$( echo "${VAR}=${VALUE}" | tac - "${KFILE}" | awk '"'"'{ m = match($0,"^(\\s*\\S+)=(.*)$") ; if (m>0) { split($0,a,"="); gsub(/[ \\f\\t\\v]+/,"",a[1]); if (++seen[a[1]]<2) { print } } else { print } }'"'"' | tac )" ; echo "${LINES}" > "${KFILE}" ; } ; f'
# :: * `git bundle-encrypt`
git config --global alias.bundle-encrypt '!f() { ROOT="$(git rev-parse --show-toplevel)" || { echo "git repository error" 1>&2 ; exit 1 ; } ; BUNDIR="${ROOT}/.git/bundle" ; if [ ! -d "${BUNDIR}" ] ; then mkdir -p "${BUNDIR}" ; chmod -R go-rwx "${BUNDIR}" ; fi ; git bundle create "${BUNDIR}/git.bundle" --all ; eval "KEY="" ; SALT="" ; $(if [ -f "${BUNDIR}/git.bundle.env" ] ; then grep -E "^\s*(KEY|SALT)=" "${BUNDIR}/git.bundle.env" ; fi )" ; if [ -z "${KEY}" ] ; then KEY="$(openssl rand -base64 -rand "${BUNDIR}/git.bundle" 48)" ; echo "KEY="${KEY}"" >> "${BUNDIR}/git.bundle.env" ; fi ; if [ -z "${SALT}" ] ; then SALT="$(openssl rand -hex -rand "${BUNDIR}/git.bundle" 8)" ; echo "SALT="${SALT}"" >> "${BUNDIR}/git.bundle.env" ; fi ; rm "${BUNDIR}/git.bundle.ssl" 2>/dev/null ; openssl enc -e -aes-256-cbc -salt -salt -S "${SALT}" -k "${KEY}" -in "${BUNDIR}/git.bundle" -out "${BUNDIR}/git.bundle.ssl" 2>/dev/null ; chmod go-rwx "${BUNDIR}/git.bundle.ssl" ; } ; f'
# :: * `git bundle-push [PUSH]` # PUSH == a valid `scp` target
git config --global alias.bundle-push '!f() { ROOT="$(git rev-parse --show-toplevel)" || { echo "git repository error" 1>&2 ; exit 1 ; } ; BUNDIR="${ROOT}/.git/bundle" ; PUSH="$1"; [ -z "${PUSH}" ] && eval "PUSH="" ; $(if [ -f "${BUNDIR}/git.bundle.env" ] ; then grep -E "^\s*(PUSH)=" "${BUNDIR}/git.bundle.env" ; fi )" ; git bundle-encrypt ; if [ -n "${PUSH}" ] ; then scp "${BUNDIR}/git.bundle.ssl" "${PUSH}" ; else echo "ERR!: Missing PUSH target" 1>&2 ; exit 1 ; fi; } ; f'
# :: * `git bundle-fetch [FETCH]` # FETCH == a valid `curl` source ; from the CLI, simple file paths are converted to curl-compatible arguments
git config --global alias.bundle-fetch '!f() { ROOT="$(git rev-parse --show-toplevel)" || { echo "git repository error" 1>&2 ; exit 1 ; } ; BUNDIR="${ROOT}/.git/bundle" ; if [ ! -d "${BUNDIR}" ] ; then mkdir -p "${BUNDIR}" ; chmod -R go-rwx "${BUNDIR}" ; fi ; eval "FETCH="" ; $(if [ -f "${BUNDIR}/git.bundle.env" ] ; then grep -E "^\s*(FETCH)=" "${BUNDIR}/git.bundle.env" ; fi )" ; [ -n "$1" ] && { if [ -z "${FETCH}" ] ; then git bundle-config FETCH "$1" ; fi ; FETCH="$1" ; } ; [ -f "${FETCH}" ] && FETCH="file://$(readlink -f "${FETCH}")" ; eval "KEY="" ; $(if [ -f "${BUNDIR}/git.bundle.env" ] ; then grep -E "^\s*(KEY)=" "${BUNDIR}/git.bundle.env" ; fi )" ; OPTIONS="" ; [ -n "${KEY}" ] && OPTIONS="-k "${KEY}"" ; if [ -n "${FETCH}" ] ; then echo "FETCH=${FETCH} ; OPTIONS=${OPTIONS}" ; curl --silent -L "${FETCH}" | openssl enc -d -aes-256-cbc $OPTIONS > "${BUNDIR}/git.bundle" 2>/dev/null ; [ "$?" -ne 0 ] && echo "Decryption error" 1>&2 || git bundle unbundle "${BUNDIR}/git.bundle" ; else echo "Missing FETCH/PULL source" 1>&2 ; exit 1 ; fi ; } ; f'
# :: * `git bundle-pull [FETCH]` # FETCH == a valid `curl` source ; from the CLI, simple file paths are converted to curl-compatible arguments
git config --global alias.bundle-pull '!f() { git bundle-fetch $@ | grep -Ei "head$" | sed -E "s/\s+head//I" | xargs git checkout ; } ; f'
#
}
# echo "cd -- \"${DIR}\""
cd -- "${DIR}" || { echo "ERR!: unable to \`cd -- \"${DIR}\"\`" 1>&2 ; exit 1 ; }
git init || { echo "ERR!: unable to \`git init\` (within \"${DIR}\")" 1>&2 ; exit 1 ; }
echo "git bundle-config FETCH \"${FETCH}\""
git bundle-config FETCH "${FETCH}" || { echo "ERR!: \`git bundle-config FETCH \"${FETCH}\"\` failed (within \"${DIR}\")" 1>&2 ; exit 1 ; }
echo "git bundle-pull"
git -c advice.detachedhead=false bundle-pull || { echo "ERR!: \`git bundle-pull\` failed (within \"${DIR}\")" 1>&2 ; exit 1 ; }
# echo "git bundle-pull \"${FETCH}\""
# git bundle-pull "${FETCH}" || { echo "ERR!: \`git bundle-pull \"${FETCH}\"\` failed (within \"${DIR}\")" 1>&2 ; exit 1 ; } ;
echo "chmod -R go-rwx \"${DIR}\""
chmod -R go-rwx "${DIR}" || { echo "ERR!: \`chmod failed (within \"${DIR}\")" 1>&2 ; exit 1 ; }
