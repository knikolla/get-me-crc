# This script uses a clouds.yaml file to connect to an OpenStack cloud
# and set up a VM onto which to install CodeReady containers.
#
# TODO: Check corresponding OpenShift version to CRC
# The installed version of OpenShift is whatever 1.32.1 crc installs.
#
# Requires the following environment variables set
#   CRC_PULL_STRING
#   GITHUB_REF
#
# Requires a clouds.yaml file with a cloud named openstack
#
# Expects to be run from root directory of repo.

set -e

# Configure clouds.yaml
# TODO: Change this to cloud name openstack
osc_cmd="openstack --os-cloud _knikolla"

# Create ssh key
# TODO: Only create the key if the file doesn't exist!
# ssh-keygen -b 2048 -t rsa -f temp/sshkey -q -N ""

# Create stack
# TODO: Check if stack already exists!
# $osc_cmd stack create "openshift-acct-mgt-$GITHUB_REF" \
#   -t src/crc_heat_template.yaml \
#  --parameter name="openshift-acct-mgt-$GITHUB_REF" \
# --parameter public_key="$(cat temp/sshkey.pub)"

# Wait until stack creation
# TODO: Add error detection for CREATE_FAILED status
status_cmd="$osc_cmd stack show openshift-acct-mgt-$GITHUB_REF -f value -c stack_status"
while [ "$($status_cmd)" != "CREATE_COMPLETE" ]
do
  echo "Waiting for Stack Creation..."
  sleep 10
done

# Get server IP and wait for SSH up
server_ip="$($osc_cmd stack output show openshift-acct-mgt-$GITHUB_REF server_ip -f value -c output_value)"
ssh_options="-i temp/sshkey -oStrictHostKeyChecking=no -o IdentitiesOnly=yes"

until ssh $ssh_options "centos@$server_ip" exit
do
  echo "Waiting for SSH connection..."
  sleep 10
done

echo "$CRC_PULL_STRING" > temp/pullstring.json

scp $ssh_options \
  -r src "centos@$server_ip:/home/centos/"

scp $ssh_options \
    temp/pullstring.json "centos@$server_ip:/home/centos/"

# Install CRC
ssh $ssh_options "centos@$server_ip" \
  "./src/setup.sh pullstring.json"
