CERT="$1"
KEY="$2"

NAME="${HOSTNAME}"
BASE_URL="https://store.seguro.eonerc.rwth-aachen.de/certificates"

mkdir -p "$(dirname "${CERT}")" "$(dirname "${KEY}")"

curl -sk "${BASE_URL}/${NAME}.crt" > "${CERT}"
curl -sk "${BASE_URL}/${NAME}.key" > "${KEY}"