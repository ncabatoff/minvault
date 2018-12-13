#!/bin/bash

set -e

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y unzip jq

VAULT_VERSION=1.0.0
VAULT_ARCH=linux_amd64
VAULT_ZIP=vault_${VAULT_VERSION}_${VAULT_ARCH}.zip

echo "Fetching vault"
cd /tmp
wget -q https://releases.hashicorp.com/vault/${VAULT_VERSION}/${VAULT_ZIP}
unzip -o /tmp/$VAULT_ZIP
mv vault /usr/local/bin/vault
setcap cap_ipc_lock+ep /usr/local/bin/vault

id -u vault &>/dev/null || sudo useradd -r -d /var/lib/vault -s /bin/nologin vault
install -o vault -g vault -m 750 -d /var/vault

# Clean up in case we're re-run, start fresh.
systemctl stop vault 2>/dev/null || true
rm -rf /var/vault/data 2>/dev/null || true

cp /vagrant/vault.hcl /etc/
cp /vagrant/vault.service /etc/systemd/system/

echo "Starting vault"
systemctl daemon-reload
systemctl start vault

VAULT_PORT=8200
export VAULT_ADDR=http://localhost:$VAULT_PORT
sed -i /^VAULT_ADDR=/d /etc/environment
echo "VAULT_ADDR=$VAULT_ADDR" >> /etc/environment

while ! nc -z localhost $VAULT_PORT; do
  sleep 1
  echo -n '.'
done
echo

echo "Initialing and unsealing vault"

# WARNING: This is not a secure way to initialize vault.  This is for a demo/toy.
initoutput=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)
unsealkey=$(echo "$initoutput" | jq -r .unseal_keys_hex[0])
roottoken=$(echo "$initoutput" | jq -r .root_token)
vault operator unseal "$unsealkey"

vault status

echo
echo "Unseal key is '$unsealkey', you will need it to unseal vault if you restart it."
echo "Alternatively, you can run 'vagrant provision' from the host machine but you will lose all vault data."
echo
echo "Root token is '$roottoken'."