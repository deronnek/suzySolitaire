#!/bin/zsh
# Unlocks the Debug menu on one phone running a TestFlight build.  Long-press the score on the felt to see the phone's
# code, then:
#
#   scripts/debug-unlock.sh ABCD-1234
#
# and paste what it prints into the same box on the phone.  The unlock works only on the phone with that code.
#
# It signs with the private key at ~/.suze-solitaire/debug-unlock-key.pem (or DEBUG_UNLOCK_KEY), which never goes in the
# repo; ViewController+Debug.swift holds the public half.  Without the key, make a new pair with --new-key, put the
# public key it prints in DebugAccess.publicKey, and ship a build: unlocks from the old key stop working.
set -euo pipefail

KEY=${DEBUG_UNLOCK_KEY:-$HOME/.suze-solitaire/debug-unlock-key.pem}

if [[ ${1:-} == --new-key ]]; then
    [[ -e $KEY ]] && { echo "$KEY already exists; move it away first" >&2; exit 1; }
    mkdir -p "$(dirname "$KEY")"
    chmod 700 "$(dirname "$KEY")"
    (umask 077; openssl ecparam -name prime256v1 -genkey -noout -out "$KEY")
    echo "New key: $KEY"
    echo "Public key for DebugAccess.publicKey:"
    openssl ec -in "$KEY" -pubout -outform DER 2>/dev/null | tail -c 65 | base64
    exit 0
fi

[[ $# == 1 ]] || { echo "Usage: $0 <phone's code> | --new-key" >&2; exit 1; }
[[ -r $KEY ]] || { echo "No key at $KEY (set DEBUG_UNLOCK_KEY, or make one with --new-key)" >&2; exit 1; }
# The code as the app shows it, in any case, with or without the dash
code=$(echo "$1" | tr -d ' -' | tr '[:lower:]' '[:upper:]')
[[ $code =~ ^[0-9A-Z]{8}$ ]] || { echo "A phone's code is eight letters and digits, like ABCD-1234" >&2; exit 1; }
printf 'Suze Solitaire debug unlock %s' "$code" | openssl dgst -sha256 -sign "$KEY" | base64 | tr -d '\n=' | tr '+/' '-_'
echo
