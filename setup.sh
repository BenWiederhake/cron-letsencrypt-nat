#!/bin/sh

set -ex
cd "$(dirname "$0")"

# Check arguments
if [ "$#" != "1" ] || [ -e "$1" ]
then
    echo "USAGE: $0 <DOMAIN>"
    echo "<DOMAIN> also must be a valid sub-directory name,"
    echo "and must not exist yet."
    exit 1
fi
domain="$1"

# Fail early if something's missing:
for cmd in git openssl acme-tiny timeout python3 ; do
    if ! command -v "$cmd" >/dev/null 2>&1 ; then
        echo "No '$cmd' available. Are you sure you want to use this type of setup?"
        exit 1
    fi
done

# Create
umask 0077 || echo "Couldn't tighten umask. Ignoring."
mkdir "${domain}"
cd "${domain}"

# Set up git to be usable
git init
echo "tmp-serve-*" > .gitignore
git add .gitignore
git commit -m "Initial commit: the ignorefile"

# Set up private keys
# (Inspired by https://github.com/diafygi/acme-tiny#how-to-use-this-script )
openssl genrsa 4096 > account.key
openssl genrsa 4096 > domain.key
openssl req -new -sha256 -key domain.key -subj "/CN=${domain}" > domain.csr
git add account.key domain.key domain.csr
git commit -m "Generate private keys"

# Try to push, or tell when the git repo couldn't be guessed:
git remote add origin ssh://private_git/cert-"${domain}".git
git push -u origin master || {
    # Don't echo the echo command.
    set +x
    echo "Look's like 'ssh://private_git' isn't in your ssh config."
    echo "Before you continue, configure upstream properly, for example:"
    echo "    git remote set-url origin ssh://internal_git/cert-${domain}.git"
    echo "'exit 1'ing for better visibility, even though the script was successful."
    exit 1
}
