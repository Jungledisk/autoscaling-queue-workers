#!/usr/bin/env bash

dnf install -y ansible awscli jq python-boto3 python-boto \
               libselinux-python

cat <<"EOF" > /home/${ssh_user}/update_ssh_authorized_keys.sh
#!/usr/bin/env bash
set -e
BUCKET_URI=s3://${ssh_bucket}/${ssh_prefix}
MARKER="# KEYS_BELOW_WILL_BE_UPDATED_BY_TERRAFORM"
KEYS_FILE=/home/${ssh_user}/.ssh/authorized_keys
TEMP_KEYS_FILE=$(mktemp)
PUB_KEYS_DIR=/home/${ssh_user}/pub_key_files/

mkdir -p $PUB_KEYS_DIR

# Add marker, if not present, and copy static content.
grep -Fxq "$MARKER" $KEYS_FILE || echo -e "\n$MARKER" >> $KEYS_FILE
line=$(grep -n "$MARKER" $KEYS_FILE | cut -d ":" -f 1)
head -n $line $KEYS_FILE > $TEMP_KEYS_FILE

# Synchronize the keys from the bucket.
aws s3 sync --delete $BUCKET_URI $PUB_KEYS_DIR

for filename in $PUB_KEYS_DIR/*; do
    sed 's/\n\?$/\n/' < $filename >> $TEMP_KEYS_FILE
done

# Move the new authorized keys in place.
mv $TEMP_KEYS_FILE $KEYS_FILE
chown ${ssh_user}:${ssh_user} $KEYS_FILE
chmod 600 $KEYS_FILE

if selinuxenabled; then
    restorecon -R -v $KEYS_FILE
fi
EOF

cat <<"EOF" > /home/${ssh_user}/.ssh/config
Host *
    StrictHostKeyChecking no
EOF

chmod 600 /home/${ssh_user}/.ssh/config
chown ${ssh_user}:${ssh_user} /home/${ssh_user}/.ssh/config

chown ${ssh_user}:${ssh_user} /home/${ssh_user}/update_ssh_authorized_keys.sh
chmod 755 /home/${ssh_user}/update_ssh_authorized_keys.sh

# Execute now
su ${ssh_user} -c /home/${ssh_user}/update_ssh_authorized_keys.sh

# Add to cron
if [ -n "${ssh_keys_cron}" ]; then
  croncmd="/home/${ssh_user}/update_ssh_authorized_keys.sh"
  cronjob="${ssh_keys_cron} $croncmd"
  ( crontab -u ${ssh_user} -l | grep -v "$croncmd"
    echo "$cronjob" ) | crontab -u ${ssh_user} -
fi

aws s3 cp s3://${ansible_bucket}/${ansible_vault_file} /root/.vault

chmod 700 /root/.vault
chown root:root /root/.vault

ANSIBLE_DIR=/root/${ansible_prefix}
mkdir -p $ANSIBLE_DIR
aws s3 sync --delete s3://${ansible_bucket}/${ansible_prefix} $ANSIBLE_DIR
#ansible-galaxy install -r $ANSIBLE_DIR/requirements.yml
# NOTE(jkoelker) run it twice due to RH1398272 importing gpg key locking rpmdb
ansible-playbook --vault-password-file=/root/.vault \
                 -i "localhost," -c local $ANSIBLE_DIR/master.yml || \
    ansible-playbook --vault-password-file=/root/.vault \
                     -i "localhost," -c local $ANSIBLE_DIR/master.yml
