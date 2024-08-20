# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{writeShellApplication, openssl, tpm2-openssl, jq, tpm2-tools, ...}: writeShellApplication {
  name = "seguro-generate-keys";
  runtimeInputs = [
    openssl
    tpm2-tools
    jq
  ];

  text = ''
    set -e

    export OPENSSL_MODULES="${tpm2-openssl}/lib/ossl-modules"

    HAS_TPM=$(tpm2_getcap algorithms > /dev/null && echo 1)
    CN=$(jq -r .uid < /boot/firmware/gateway.json)

    if [ -z "$CN" ]; then
      echo "Missing 'uid' setting"
      exit 1
    fi

    if [ -n "$HAS_TPM" ]; then
      OPENSSL_OPTS=(-provider tpm2 -provider base -propquery "?provider=tpm2")
    fi

    KEY_DIR="$(dirname "$TLS_KEY")"
    mkdir -p "$KEY_DIR"

    # shellcheck disable=SC2068
    openssl genpkey ''${OPENSSL_OPTS[@]} \
      -algorithm EC \
      -pkeyopt group:P-256 \
      -out "$TLS_KEY"

    # shellcheck disable=SC2068
    openssl req ''${OPENSSL_OPTS[@]} \
      -new \
      -key "$TLS_KEY" \
      -out "$TLS_CSR" \
      -subj "/CN=$CN/O=SEGuRo Project/C=DE"
  '';
}
