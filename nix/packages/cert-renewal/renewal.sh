#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

################################################################################
#
# Script for renewing TLS certificates using EST (Enrollment over Secure Transport)
# using certificate authentication.
#
# See: https://doc.nexusgroup.com/pub/est-support-in-certificate-manager
#

set -e

################################################################################
#
# Prepare
#


# Check if required environment variables are set
if [ -z "${EST_URL}" ]; then
    echo "Please set the EST_URL environment variable."
    exit 1
fi

if [ -z "${CERT}" ]; then
    echo "Please set the CERT environment variable."
    exit 1
fi

if [ -z "${CACERT}" ]; then
    echo "Please set the CACERT environment variable."
    exit 1
fi

if [ -z "${KEY}" ]; then
    echo "Please set the KEY environment variable."
    exit 1
fi

if [ -z "${CSR_COMMON_NAME}" ]; then
    echo "Please set the CSR_COMMON_NAME environment variable."
    exit 1
fi

for i in curl openssl ; do
	if ! which "$i" >/dev/null 2>/dev/null; then
		echo "ERROR: Cannot find \"$i\", which is required by this script"
		exit 1
	fi
done

# Temporary files
CSR="$(mktemp -t csr.XXXXXX)"
CERT_NEW="$(mktemp -t cert.XXXXXX)"
KEY_NEW="$(mktemp -t key.XXXXXX)"
CERT_P12="$(mktemp -t cert.p12.XXXXXX)"
KEY_OLD="${KEY}.old-$(date +%s)"
CERT_OLD="${CERT}.old-$(date +%s)"

CURL="curl --fail-with-body"

VERBOSE=true
if [ "${1:-}" = "-q" ]; then
  VERBOSE=false
fi

if [ "${VERBOSE}" = true ]; then
  set -x
  CURL="${CURL} --verbose"
fi

# Clean up temporary files on exit
trap 'rm -f "${CSR}" "${CERT_NEW}" "${CERT_P12}"' EXIT

################################################################################
#
# Step 1: Create new key
#

openssl genrsa \
  -traditional \
  -out "${KEY_NEW}" 2048

################################################################################
#
# Step 2: Create new CSR
#

openssl req \
  -new \
  -batch \
  -key "${KEY_NEW}" \
  -nodes \
  -outform DER \
	-subj "/CN=${CSR_COMMON_NAME}" \
	-addext "subjectAltName = DNS:${CSR_COMMON_NAME}" \
| openssl base64 -e \
  > "${CSR}"


################################################################################
#
# Step 3: Request new certificate via EST
#

PASSWORD="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16; echo)"

openssl pkcs12 \
  -export \
  -in "${CERT}" \
  -inkey "${KEY}" \
  -out "${CERT_P12}" \
  -password "pass:${PASSWORD}"

${CURL} \
  --request POST \
  --header "Content-Type: application/pkcs10" \
  --header "Content-Transfer-Encoding: base64" \
  --cert-type P12 \
  --cert "${CERT_P12}:${PASSWORD}" \
  --data "@${CSR}" \
  "${EST_URL}/simplereenroll" \
> "${CERT_NEW}"


################################################################################
#
# Step 4: Make a backup of the old certificate
#

if [ -f "${CERT}" ]; then
    mv "${CERT}" "${CERT_OLD}"
fi

if [ -f "${KEY}" ]; then
    mv "${KEY}" "${KEY_OLD}"
    mv "${KEY_NEW}" "${KEY}"
fi


################################################################################
#
# Step 5: Convert the new certificate to PEM format
#

openssl base64 \
  -d \
  -in "${CERT_NEW}" | \
openssl pkcs7 \
  -inform DER \
  -outform PEM \
  -print_certs | \
openssl x509 \
  -out "${CERT}"


###############################################################################
#
# Step 6: Verify the issued certificate
#

openssl verify \
  -CAfile "${CACERT}" \
  "${CERT}"
