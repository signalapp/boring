#!/usr/bin/env bash
# Generates the certificates used by `boring/src/ssl/test/verify.rs` for the
# CRL tests.
#
# RSA PKCS#1 v1.5 signatures are deterministic, so this reproduces the
# committed files byte for byte.

set -euo pipefail

cd "$(dirname "$0")"

# Change these values to generate newer certificates.
last_update=20261015000000Z
next_update=20361012000000Z

crlnumber=1001 # 4097 in hex

W=$(mktemp -d)   # scratch dir for the openssl-ca config and state

cat > "$W/ca-v1.cnf" <<CNF
[ ca ]
default_ca = CA_default
[ CA_default ]
database   = $W/index.txt
default_md = sha256
CNF

cat > "$W/ca-v2.cnf" <<CNF
[ ca ]
default_ca = CA_default
[ CA_default ]
database       = $W/index.txt
crlnumber      = $W/crlnumber
default_md     = sha256
crl_extensions = crl_ext
[ crl_ext ]
authorityKeyIdentifier = keyid:always
CNF

gencrl() {
    openssl ca -gencrl -keyfile root-ca.key -cert root-ca.pem \
    -crl_lastupdate $last_update -crl_nextupdate $next_update "$@"
}

# empty_crl.pem: v1, no revocations
echo 'generating empty_crl.pem...'
touch "$W/index.txt"
gencrl -config "$W/ca-v1.cnf" -out empty_crl.pem

# Revoke cert.pem, then adjust the revocation timestamp to match $last_update for determinism.
openssl ca -revoke cert.pem -config "$W/ca-v1.cnf" -keyfile root-ca.key -cert root-ca.pem
sed -i '' -E -e '/^R[[:space:]]/ s/[[:digit:]]+Z/'"${last_update#20}"'/2' "$W/index.txt"
cat "$W/index.txt"

# bad_sig.pem: v1, revokes cert.pem, then the last byte of the signature is flipped
echo 'generating bad_sig.pem...'
gencrl -config "$W/ca-v1.cnf" -out "$W/good.pem"
openssl crl -in "$W/good.pem" -outform DER -out "$W/temp.der"
python3 -c 'import sys; p=sys.argv[1]; b=bytearray(open(p,"rb").read()); b[-1]^=0xFF; open(p,"wb").write(b)' "$W/temp.der"
openssl crl -inform DER -in "$W/temp.der" -out bad_sig.pem

# crl.pem: v2 with authorityKeyIdentifier and crlNumber, revokes cert.pem
echo 'generating crl.pem...'
echo $crlnumber > "$W/crlnumber"
gencrl -config "$W/ca-v2.cnf" -out crl.pem
