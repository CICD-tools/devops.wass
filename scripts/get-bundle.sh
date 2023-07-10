#! /bin/bash
# get-bundle [FETCH] [DIR]

## spell-checker:ignore (names) QNAP qpkg (shell/nix) chmod eval mkdir mktemp openssl pacman readlink shellcheck xargs (vars) KFILE OSID tmpdir HOSTDIR () detachedHead maint noConfirm gsub
## spell-checker:ignore BUNDIR devops toplevel unbundle

set -e ## '-e' == exit if pipeline fails

export FETCH="${1:-${FETCH}}"
FETCH="${FETCH:-https://rawcdn.githack.com/CICD-tools/devops.wass/master/devops.git.bundle.gpg}"
export DIR="${2:-${DIR}}"
DIR="${DIR:-${HOME}/.secrets.devops}"

DIR=$(
    mkdir -p -- "${DIR}"
    cd -- "${DIR}" || {
        echo "ERR!: unable to \`cd -- \"${DIR}\"\`" 1>&2
        exit 1
    }
    pwd
)

# echo "FETCH=${FETCH}"
# echo "DIR=${DIR}"

OSID="$(uname -s | sed 's/_NT[-].*$//i' | sed 's/"//g' | tr '[:upper:]' '[:lower:]')"
OSID_like="$(grep -i '^id_like=' /etc/os-release 2>/dev/null | sed 's/^id_like=//i' | sed 's/"//g' | tr '[:upper:]' '[:lower:]')"
OSID_name="$(grep -i '^id=' /etc/os-release 2>/dev/null | sed 's/^id=//i' | sed 's/"//g' | tr '[:upper:]' '[:lower:]')"
export OSID OSID_like OSID_name
# QNAP/QTS OSID_name fixup
[ -z "$OSID_name" ] && grep -q QNAP /etc/issue && export OSID_name=qts
[ -z "$OSID_name" ] && [ -f /etc/config/qpkg.conf ] && export OSID_name=qts
# OSID_like fixup
[ -z "$OSID_like" ] && export OSID_like="$OSID_name"

# case "$OSID_name" in
#     "kali" )
#         # `wsl --install ...` kali-linux is *old* and has expired keys
#         # ref: <https://unix.stackexchange.com/questions/421821/invalid-signature-for-kali-linux-repositories-the-following-signatures-were-i>
#         # !maint: KEY_FILENAME will likely need to be updated periodically
#         DEST_FILE=$(mktemp kali-keyring.XXXXXXXXXX --suffix=.deb --tmpdir)
#         KEY_HOSTDIR="https://http.kali.org/kali/pool/main/k/kali-archive-keyring"
#         KEY_FILENAME="kali-archive-keyring_2022.1_all.deb"
#         wget --no-check-certificate "${KEY_HOSTDIR}/${KEY_FILENAME}" -O "${DEST_FILE}"
#         sudo dpkg -i "${DEST_FILE}"
#     ;;
# esac

case "$OSID_like" in
"arch") _INSTALL_deps="pacman -S --refresh && pacman -S --noconfirm git gpg" ;;
"suse") _INSTALL_deps="zypper refresh && zypper install --no-confirm git gpg" ;;
*) _INSTALL_deps="sudo apt-get update && sudo apt-get install --assume-yes git gpg" ;; # debian-like is default
esac

# require `git`
which git >/dev/null || { eval "${_INSTALL_deps}" || {
    echo "ERR!: unable to install \`git\`" >&2
    exit 1
}; }

# shellcheck disable=SC2016
{
    # setup `git` bundle aliases
    # :: * `git bundle-config [VAR [VALUE]]` # VAR == a valid POSIX shell variable name ; VALUE == optional configuration value to be saved (defaults to current value of shell VAR); with no arguments, prints current configuration
    git config --global alias.bundle-config '!f() { ROOT="$(git rev-parse --show-toplevel)" || { echo "git repository error" 1>&2 ; exit 1 ; } ; BUNDIR="${ROOT}/.git/bundle" ; if [ ! -d "${BUNDIR}" ] ; then mkdir -p "${BUNDIR}" ; chmod -R go-rwx "${BUNDIR}" ; fi ; KFILE="${BUNDIR}/git.bundle.env" ; if [ ! -e "${KFILE}" ] ; then touch "${KFILE}" ; chmod go-rwx "${KFILE}" ; fi ; VAR="$1" ; [ -n "${VAR}" ] || { cat "${KFILE}" ; exit 0 ; } ; VALUE="${2}" ; [ -z "${VALUE}" ] && eval "VALUE=\$${VAR}" ; LINES="$( echo "${VAR}=${VALUE}" | tac - "${KFILE}" | awk '"'"'{ m = match($0,"^(\\s*\\S+)=(.*)$") ; if (m>0) { split($0,a,"="); gsub(/\s+/,"",a[1]); if (++seen[a[1]]<2) { print } } else { print } }'"'"' | tac )" ; echo "${LINES}" > "${KFILE}" ; } ; f'
    # :: * `git bundle-encrypt`
    git config --global alias.bundle-encrypt '!f() { ROOT="$(git rev-parse --show-toplevel)" || { echo "git repository error" 1>&2 ; exit 1 ; } ; BUNDIR="${ROOT}/.git/bundle" ; if [ ! -d "${BUNDIR}" ] ; then mkdir -p "${BUNDIR}" ; chmod -R go-rwx "${BUNDIR}" ; fi ; git bundle create "${BUNDIR}/git.bundle" --all ; eval "KEY="" ; $(if [ -f "${BUNDIR}/git.bundle.env" ] ; then grep -E "^\s*(KEY)=" "${BUNDIR}/git.bundle.env" ; fi )" ; if [ -z "${KEY}" ] ; then KEY="$(openssl rand -base64 -rand "${BUNDIR}/git.bundle" 48)" ; echo "KEY="${KEY}"" >> "${BUNDIR}/git.bundle.env" ; fi ; rm "${BUNDIR}/git.bundle.gpg" 2>/dev/null ; gpg --symmetric -z 9 --batch --yes --passphrase "${KEY}" "${BUNDIR}/git.bundle" ; chmod go-rwx "${BUNDIR}/git.bundle.gpg" ; } ; f'
    # :: * `git bundle-push [PUSH]` # PUSH == a valid `scp` target
    git config --global alias.bundle-push '!f() { ROOT="$(git rev-parse --show-toplevel)" || { echo "git repository error" 1>&2 ; exit 1 ; } ; BUNDIR="${ROOT}/.git/bundle" ; PUSH="$1"; [ -z "${PUSH}" ] && eval "PUSH="" ; $(if [ -f "${BUNDIR}/git.bundle.env" ] ; then grep -E "^\s*(PUSH)=" "${BUNDIR}/git.bundle.env" ; fi )" ; git bundle-encrypt ; if [ -n "${PUSH}" ] ; then scp "${BUNDIR}/git.bundle.gpg" "${PUSH}" ; else echo "ERR!: missing PUSH target" 1>&2 ; exit 1 ; fi; } ; f'
    # :: * `git bundle-fetch [FETCH]` # FETCH == a valid `curl` source ; from the CLI, simple file paths are converted to curl-compatible arguments
    git config --global alias.bundle-fetch '!f() { ROOT="$(git rev-parse --show-toplevel)" || { echo "git repository error" 1>&2 ; exit 1 ; } ; BUNDIR="${ROOT}/.git/bundle" ; if [ ! -d "${BUNDIR}" ] ; then mkdir -p "${BUNDIR}" ; chmod -R go-rwx "${BUNDIR}" ; fi ; FETCHER="curl -#L" ; eval "FETCH="" ; $(if [ -f "${BUNDIR}/git.bundle.env" ] ; then grep -E "^\s*(FETCH)=" "${BUNDIR}/git.bundle.env" ; fi )" ; [ -n "$1" ] && { if [ -z "${FETCH}" ] ; then git bundle-config FETCH "$1" ; fi ; FETCH="$1" ; } ; [ -f "${FETCH}" ] && { FETCH="$(readlink -f "${FETCH}")" ; FETCHER="cat" ; } ; eval "KEY="" ; $(if [ -f "${BUNDIR}/git.bundle.env" ] ; then grep -E "^\s*(KEY)=" "${BUNDIR}/git.bundle.env" ; fi )" ; OPTIONS="--passphrase "${KEY}"" ; if [ -n "${FETCH}" ] ; then echo "FETCHER=${FETCHER} ; FETCH=${FETCH}" ; ${FETCHER} "${FETCH}" | gpg --decrypt --batch --yes ${OPTIONS} > "${BUNDIR}/git.bundle" ; [ "$?" -ne 0 ] && { echo "ERR!: decryption error" 1>&2 ; exit 1 ; } || git bundle unbundle "${BUNDIR}/git.bundle" ; else echo "ERR!: missing FETCH/PULL source" 1>&2 ; exit 1 ; fi ; } ; f'
    # :: * `git bundle-pull [FETCH]` # FETCH == a valid `curl` source ; from the CLI, simple file paths are converted to curl-compatible arguments
    git config --global alias.bundle-pull '!f() { git bundle-fetch $@ | grep -Ei "head$" | sed -E "s/\s+head//I" | xargs git checkout ; } ; f'
    #
}
# echo "cd -- \"${DIR}\""
cd -- "${DIR}" || {
    echo "ERR!: unable to \`cd -- \"${DIR}\"\`" 1>&2
    exit 1
}
git init || {
    echo "ERR!: unable to \`git init\` (within \"${DIR}\")" 1>&2
    exit 1
}
echo "git bundle-config FETCH \"${FETCH}\""
git bundle-config FETCH "${FETCH}" || {
    echo "ERR!: \`git bundle-config FETCH \"${FETCH}\"\` failed (within \"${DIR}\")" 1>&2
    exit 1
}
echo "git bundle-pull"
git -c advice.detachedhead=false bundle-pull || {
    echo "ERR!: \`git bundle-pull\` failed (within \"${DIR}\")" 1>&2
    exit 1
}
# echo "git bundle-pull \"${FETCH}\""
# git bundle-pull "${FETCH}" || { echo "ERR!: \`git bundle-pull \"${FETCH}\"\` failed (within \"${DIR}\")" 1>&2 ; exit 1 ; } ;
echo "chmod -R go-rwx \"${DIR}\""
chmod -R go-rwx "${DIR}" || {
    echo "ERR!: \`chmod failed (within \"${DIR}\")" 1>&2
    exit 1
}
