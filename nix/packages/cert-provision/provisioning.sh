#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-FileCopyrightText: 2025 Nexus Group
# SPDX-License-Identifier: Apache-2.0

################################################################################
#
# Example script for calling the CM REST API endpoints using curl
#
# This script uses TLS client & server certificates for authentication, which
# must be configured before executing.
#
# See: https://doc.nexusgroup.com/pub/certificate-manager-cm-rest-api
#

set -e

################################################################################
#
# Prepare
#

PGWY_HOST=${PGWY_HOST:-"iotpocenvironment.westeurope.cloudapp.azure.com"}
PGWY_CERT=${PGWY_CERT:-"iot_poc_environment.pem"}

INSTANCE=${INSTANCE:-"smartgrid_herne"}

PGWY_API_URL=${PGWY_API_URL:-"https://${PGWY_HOST}:8444/pgwy/api/${INSTANCE}"}
PGWY_DP_URL=${PGWY_DP_URL:-"http://${PGWY_HOST}:8080/pgwy/dp"}

OFFICER_CERT=${OFFICER_CERT:-"smartgrid_herne_vro.p12.pem"}

CA_CERT_NAMES=${CA_CERT_NAMES:-"smartgrid_herne_issuing_ca poc_nexus_go_iot_rsa_policy_ca_g1 poc_nexus_go_iot_rsa_root_ca_g1"}

CSR_COMMON_NAME=${CSR_COMMON_NAME:-"loc1"}
CSR_SUBJECT=${CSR_SUBJECT:-"/CN=${CSR_COMMON_NAME}/O=Nexus/C=SE"}

OUTPUT_DIR=${OUTPUT_DIR:-${PWD}}

KEY="${OUTPUT_DIR}/key-${CSR_COMMON_NAME}.pem"
CERT="${OUTPUT_DIR}/cert-${CSR_COMMON_NAME}.pem"

################################################################################
#
# Checks
#

if [ -z "${PGWY_API_URL}" -o -z "${PGWY_DP_URL}" ]; then
  echo "Please set the PGWY_API_URL and PGWY_DP_URL environment variables."
  exit 1
fi

if [ -z "${PGWY_CERT}" ]; then
  echo "Please set the PGWY_CERT environment variable."
  exit 1
fi

if [ -z "${OFFICER_CERT}" ]; then
  echo "Please set the OFFICER_CERT environment variable."
  exit 1
fi

if [ -z "${CSR_SUBJECT}" ]; then
  echo "Please set the CSR_SUBJECT environment variable."
  exit 1
fi

if ! [ -f "${OFFICER_CERT}" ]; then
  echo "Cannot find OFFICER_CERT at ${OFFICER_CERT}"
  exit 1
fi

for i in curl openssl jq; do
	if ! which "${i}" >/dev/null 2>/dev/null; then
		echo "ERROR: Cannot find \"$i\", which is required by this script"
		exit 1
	fi
done

# Create output directory if it does not exist
mkdir -p "${OUTPUT_DIR}"

# Check if required tools are installed
CURL="curl \
	--cert   ${OFFICER_CERT} \
  --cacert ${PGWY_CERT} \
	--show-error"

# Temporary files
CSR_P10="$(mktemp -t request.p10.XXXXXX)"
SIG="$(mktemp -t signature.p7b.XXXXXX)"
CERT_P7B="$(mktemp -t issued-cert.p7b.XXXXXX)"

# Clean up temporary files on exit
trap 'rm -f "${CSR_P10}" "${SIG}" "${CERT_P7B}"' EXIT

VERBOSE=true
if [ "$1" = "-q" ]; then
  VERBOSE=false
fi

if [ "${VERBOSE}" = true ]; then
  set -x
  CURL="${CURL} --verbose"
fi


###############################################################################
#
# Step 2: Download CA certificates
#

for CA_CERT_NAME in ${CA_CERT_NAMES}; do
  ${CURL} "${PGWY_DP_URL}/ca/${CA_CERT_NAME}.cer" | \
  openssl x509 \
    -inform DER \
    -outform PEM \
    -out "${OUTPUT_DIR}/${CA_CERT_NAME}.pem"

    cat ${OUTPUT_DIR}/${CA_CERT_NAME}.pem >> "${OUTPUT_DIR}/cacert.pem"
done


###############################################################################
#
# Step 3: Generate & send PKCS#10 request
#

openssl req \
	-batch \
	-newkey rsa:2048 \
	-keyout "${KEY}" \
	-nodes \
	-outform DER \
	-subj "${CSR_SUBJECT}" \
| openssl base64 -e \
> "${CSR_P10}"

# Send request to process PKCS#10 in order to get "dataToSign"
${CURL} \
	--form "pkcs10=@${CSR_P10}" \
	"${PGWY_API_URL}/certificates/pkcs10" \
| jq -r .dataToSign \
| openssl base64 -d -A \
| openssl cms \
	-sign \
	-signer "${OFFICER_CERT}" \
	-binary \
	-outform DER \
	-nodetach \
| openssl base64 -e \
> "${SIG}"

# Re-send request to process PKCS#10, now with signature
${CURL} \
	--form "pkcs10=@${CSR_P10}" \
	--form "signature=@${SIG}" \
	"${PGWY_API_URL}/certificates/pkcs10" \
> "${CERT_P7B}"


###############################################################################
#
# Step 4: Extract certificate(s) from PKCS#7 structure
#

openssl pkcs7 \
	-in "${CERT_P7B}" \
	-inform DER \
	-print_certs \
	-out "${CERT}"

# Display issued certificate
if [ "${VERBOSE}" = true ]; then
  echo "Step 3, issued certificate from PKCS#10:"
	openssl x509 \
    -text \
    -noout \
    -in "${CERT}"
fi


###############################################################################
#
# Step 5: Verify the issued certificate
#

openssl verify \
  -CAfile "${OUTPUT_DIR}/cacert.pem" \
  "${CERT}"
