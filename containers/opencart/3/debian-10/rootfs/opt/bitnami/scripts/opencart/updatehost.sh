#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purpose

# Load OpenCart environment
. /opt/bitnami/scripts/opencart-env.sh

# Load libraries
. /opt/bitnami/scripts/libopencart.sh

DOMAIN="${1:?missing host}"

opencart_update_hostname "$DOMAIN"
