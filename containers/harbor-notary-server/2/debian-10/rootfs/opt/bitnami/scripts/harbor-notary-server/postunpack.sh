#!/bin/bash

# shellcheck disable=SC1091

# Load libraries
. /opt/bitnami/scripts/libfs.sh

# Ensure a set of directories exist
for dir in "/etc/notary"; do
    ensure_dir_exists "$dir"
done

# Ensure the non-root user has writing permission at a set of directories
chmod -R g+rwX "/etc/notary"

# Fix for CentOS Internal TLS
if [[ -f /etc/pki/tls/certs/ca-bundle.crt ]]; then
    chmod g+w /etc/pki/tls/certs/ca-bundle.crt
    chmod g+w /etc/pki/tls/certs/ca-bundle.trust.crt
fi
