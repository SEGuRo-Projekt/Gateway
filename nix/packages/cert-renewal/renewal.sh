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

if [ -z "${CSR_SUBJECT}" ]; then
    echo "Please set the CSR_SUBJECT environment variable."
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
CERT_OLD="${CERT}.old-$(date +%s)"

# Clean up temporary files on exit
trap 'rm -f "${CSR}" "${CERT_NEW}"' EXIT

################################################################################
#
# Step 1: Create new CSR
#

openssl req \
  -new \
  -batch \
  -key "${KEY}" \
  -nodes \
  -outform PEM \
  -subj "${CSR_SUBJECT}" \
  > "${CSR}"

################################################################################
#
# Step 2: Request new certificate via EST
#

curl \
  -v \
  --header 'Content-Type: application/pkcs10' \
  --header "Content-Transfer-Encoding: base64" \
  --location \
  --request POST \
  --cert "${CERT}" \
  --key "${KEY}" \
  --data-binary "@${CSR}" \
  "${EST_URL}/simplereenroll" \
> "${CERT_NEW}"


################################################################################
#
# Step 3: Verify the new certificate
#

### TODO

# Step 4: Make a backup of the old certificate

if [ -f "${CERT}" ]; then
    mv "${CERT}" "${CERT_OLD}"
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
