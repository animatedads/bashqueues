# Reference-only local OCI deploy example from Architect input.
# This is not called by tests or helpers; use providers.d/cloud_infra/oci_free_stack.sh for registry-gated operation.
#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Deterministic OCI Always Free Stack Deployment (London)
# Auto-loads Compartment from ~/.oci/config and SSH Key from ~/.oci/
# ==============================================================================

echo "----------------------------------------------------"
echo "1. Discovering Local Configuration..."
echo "----------------------------------------------------"

OCI_CONFIG_FILE="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"

if [[ ! -f "$OCI_CONFIG_FILE" ]]; then
    echo "Error: OCI config file not found at $OCI_CONFIG_FILE"
    exit 1
fi

# Extract compartment-id, fallback to tenancy if compartment-id is not explicitly defined
COMPARTMENT_ID=$(grep -m 1 -iE '^[[:space:]]*compartment-id[[:space:]]*=' "$OCI_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' \r\n"' || true)

if [[ -z "$COMPARTMENT_ID" ]]; then
    echo "Info: 'compartment-id' not found in config, using 'tenancy' as root compartment."
    COMPARTMENT_ID=$(grep -m 1 -iE '^[[:space:]]*tenancy[[:space:]]*=' "$OCI_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' \r\n"')
fi

if [[ -z "$COMPARTMENT_ID" ]]; then
    echo "Error: Could not extract compartment-id or tenancy from $OCI_CONFIG_FILE"
    exit 1
fi
echo "Using Compartment OCID : $COMPARTMENT_ID"

# Find the first .pub key in the ~/.oci directory
SSH_PUBLIC_KEY_FILE=$(find "$HOME/.oci" -maxdepth 1 -name "*.pub" | head -n 1 || true)

if [[ -z "$SSH_PUBLIC_KEY_FILE" ]]; then
    echo "Error: Could not find any .pub SSH key in $HOME/.oci/"
    exit 1
fi
echo "Using SSH Public Key   : $SSH_PUBLIC_KEY_FILE"


# Network and Instance Variables
PREFIX="lon-free"
SHAPE="VM.Standard.E2.1.Micro"
VCN_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.0.0/24"

echo "----------------------------------------------------"
echo "2. Discovering Infrastructure Parameters..."
echo "----------------------------------------------------"

echo -n "Fetching Availability Domain 1... "
AD=$(oci iam availability-domain list -c "$COMPARTMENT_ID" --query 'data[0].name' --raw-output)
echo "[$AD]"

echo -n "Fetching latest Oracle Linux 8 Image ID... "
IMAGE_ID=$(oci compute image list \
    -c "$COMPARTMENT_ID" \
    --operating-system "Oracle Linux" \
    --operating-system-version "8" \
    --shape "$SHAPE" \
    --sort-by TIMECREATED \
    --sort-order DESC \
    --query 'data[0].id' --raw-output)
echo "[Found]"

echo "----------------------------------------------------"
echo "3. Provisioning Network Stack..."
echo "----------------------------------------------------"

echo -n "Creating VCN ($VCN_CIDR)... "
VCN_ID=$(oci network vcn create -c "$COMPARTMENT_ID" --cidr-block "$VCN_CIDR" \
    --display-name "${PREFIX}-vcn" --dns-label "lonfree" \
    --wait-for-state AVAILABLE --query 'data.id' --raw-output)
echo "[Done]"

echo -n "Creating Internet Gateway... "
IGW_ID=$(oci network internet-gateway create -c "$COMPARTMENT_ID" --vcn-id "$VCN_ID" \
    --is-enabled true --display-name "${PREFIX}-igw" \
    --wait-for-state AVAILABLE --query 'data.id' --raw-output)
echo "[Done]"

echo -n "Creating Route Table... "
ROUTE_RULES='[{"networkEntityId":"'$IGW_ID'","destination":"0.0.0.0/0","destinationType":"CIDR_BLOCK"}]'
RT_ID=$(oci network route-table create -c "$COMPARTMENT_ID" --vcn-id "$VCN_ID" \
    --display-name "${PREFIX}-rt" --route-rules "$ROUTE_RULES" \
    --wait-for-state AVAILABLE --query 'data.id' --raw-output)
echo "[Done]"

echo -n "Creating Security List (Allowing Inbound SSH)... "
EGRESS_RULES='[{"destination":"0.0.0.0/0","protocol":"all","isStateless":false}]'
INGRESS_RULES='[{"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"max":22,"min":22}}}]'
SL_ID=$(oci network security-list create -c "$COMPARTMENT_ID" --vcn-id "$VCN_ID" \
    --display-name "${PREFIX}-sl" --egress-security-rules "$EGRESS_RULES" \
    --ingress-security-rules "$INGRESS_RULES" \
    --wait-for-state AVAILABLE --query 'data.id' --raw-output)
echo "[Done]"

echo -n "Creating Public Subnet ($SUBNET_CIDR)... "
SUBNET_ID=$(oci network subnet create -c "$COMPARTMENT_ID" --vcn-id "$VCN_ID" \
    --cidr-block "$SUBNET_CIDR" --display-name "${PREFIX}-public-subnet" \
    --route-table-id "$RT_ID" --security-list-ids '["'$SL_ID'"]' \
    --availability-domain "$AD" --wait-for-state AVAILABLE --query 'data.id' --raw-output)
echo "[Done]"

echo "----------------------------------------------------"
echo "4. Provisioning Compute Instance..."
echo "----------------------------------------------------"

echo "Launching Always Free instance. This may take a minute..."
INSTANCE_ID=$(oci compute instance launch \
    -c "$COMPARTMENT_ID" \
    --availability-domain "$AD" \
    --shape "$SHAPE" \
    --subnet-id "$SUBNET_ID" \
    --assign-public-ip true \
    --display-name "${PREFIX}-instance" \
    --image-id "$IMAGE_ID" \
    --ssh-authorized-keys-file "$SSH_PUBLIC_KEY_FILE" \
    --wait-for-state RUNNING \
    --query 'data.id' --raw-output)
echo "Instance is RUNNING."

echo "----------------------------------------------------"
echo "5. Finalizing Configuration..."
echo "----------------------------------------------------"

echo -n "Retrieving Public IP address... "
VNIC_ATTACHMENT_ID=$(oci compute vnic-attachment list -c "$COMPARTMENT_ID" \
    --instance-id "$INSTANCE_ID" --query 'data[0].id' --raw-output)
VNIC_ID=$(oci compute vnic-attachment get --vnic-attachment-id "$VNIC_ATTACHMENT_ID" \
    --query 'data."vnic-id"' --raw-output)
PUBLIC_IP=$(oci network vnic get --vnic-id "$VNIC_ID" \
    --query 'data."public-ip"' --raw-output)
echo "[$PUBLIC_IP]"

echo ""
echo "======================================================================"
echo "Deployment Complete."
echo "Instance Public IP : $PUBLIC_IP"
echo "Connection Command : ssh -i ${SSH_PUBLIC_KEY_FILE%.pub} opc@$PUBLIC_IP"
echo "======================================================================"
