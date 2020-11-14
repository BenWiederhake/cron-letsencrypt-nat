#!/bin/sh

set -ex
cd "$(dirname "$0")"

# Check arguments
echo "$(date): Invocation"
if [ "$#" != "2" ] || ! [ -d "$1" ] || ! expr "$2" >/dev/null 2>&1
then
    echo "USAGE: $0 <DOMAIN> <PORT>"
    echo "<DOMAIN> also must be an existing sub-directory name."
    exit 1
fi
domain="$1"
port="$2"
cd "${domain}"
! [ -x ./local_hook_begin ] || ./local_hook_begin
git diff --exit-code # Assert git state

# Wait for a random amount
if [ -z "${IMPATIENT}" ]
then
     echo "$(date): Random sleep"
     ! [ -x ./local_hook_pre_sleep ] || ./local_hook_pre_sleep
     # Note that this only goes up to 23 hours, not 24. Thus this invocation
     # is incredibly likely to finish before the script gets called again,
     # even if for some reason that happens already the next day.
     SLEEP_SECONDS="$(shuf -i 10-3600 -n1)"
     # Don't print SLEEP_SECONDS in advance, just in case.
     sleep "${SLEEP_SECONDS}"
     echo "Slept for ${SLEEP_SECONDS} seconds."
     ! [ -x ./local_hook_post_sleep ] || ./local_hook_post_sleep
fi

# Verification itself
echo "$(date): Invocation start"
! [ -x ./local_hook_pre_verify ] || ./local_hook_pre_verify
git diff --exit-code
HTTPDIR="$(mktemp -d tmp-serve-http-XXXXXXXX)"
mkdir -p "${HTTPDIR}"/.well-known/acme-challenge/
# Prevent directory listing:
touch "${HTTPDIR}"/index.html
touch "${HTTPDIR}"/.well-known/acme-challenge/index.html
! [ -x ./local_hook_tamper_verify ] || ./local_hook_tamper_verify "${HTTPDIR}"
( /usr/bin/timeout -k 205s 200s python3 -m http.server -d "${HTTPDIR}" "${port}" || true ; rm -rf "${HTTPDIR}" ) &
sleep 0.5 # Just in case the python core libs load slower than acme-tiny (!)
/usr/bin/time acme-tiny --disable-check --account-key ./account.key --csr ./domain.csr \
          --acme-dir "${HTTPDIR}"/.well-known/acme-challenge/ > ./signed_chain.crt
echo "$(date): Invocation end"
# The "time" shows you how much slack there is regarding the server timeout.
! [ -x ./local_hook_post_verify ] || ./local_hook_post_verify "${HTTPDIR}"
rm -rf "${HTTPDIR}"

# Assemble single-file cert, update local git state
echo "$(date): Assemble and commit"
! [ -x ./local_hook_pre_commit ] || ./local_hook_pre_commit
! git diff --exit-code --quiet
git add signed_chain.crt
git diff --exit-code
# Note: 'lets-encrypt-x3-cross-signed.pem' is included in the .crt from the
# server, and will hopefully be updated before it expires.
cat domain.key signed_chain.crt > tls_cert.pem
! git diff --exit-code --quiet
git add tls_cert.pem
git diff --exit-code --quiet
git commit --quiet -m "Auto-update on $(date)"
! [ -x ./local_hook_post_commit ] || ./local_hook_post_commit

# Push to server
! [ -x ./local_hook_pre_push ] || ./local_hook_pre_push
git push origin master
! [ -x ./local_hook_post_push ] || ./local_hook_post_push

! [ -x ./local_hook_final ] || ./local_hook_final
echo "$(date): Certification rotation successful!"
