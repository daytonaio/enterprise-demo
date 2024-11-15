#!/bin/bash
set -e

# Custom SIGINT handler
handle_sigint() {
    echo -e "\n${ERROR} Installation interrupted by user. Exiting..."
    echo -e "${INFO} Clean up and try again, run './setup.sh --remove' and then restart the installation."
    exit 1
}

# Install the SIGINT handler
trap 'handle_sigint' SIGINT

export LC_ALL=en_US.UTF-8
export LC_CTYPE=UTF-8

start_time=$(date +%s)

OK="\033[1;32m✔\033[0m"
ERROR="\033[1;31m✘\033[0m"
INFO="\033[1;36mℹ\033[0m"

K3S_VERSION="v1.29.8+k3s1"
LONGHORN_VERSION="1.6.3"
INGRESS_NGINX_VERSION="4.11.3"
WATKINS_VERSION="2.114.1"

display_logo() {
    echo -e "\n"
    echo -e "                  -#####=           "
    echo -e "                -######-            "
    echo -e "       +###=   -######:             "
    echo -e "       ####* -#####%-.............  "
    echo -e "       ####*######:=##############- "
    echo -e "       ####* =%#-  =##############- "
    echo -e " :*%=  ####*        ....:*#:......  "
    echo -e "=####%==+++-           +####*.      "
    echo -e " :*####%=               =%####+.    "
    echo -e "   .*####%=               =%####+.  "
    echo -e "     .*###*.          .####-=%####*."
    echo -e "  :::::=%+:::::    .  .####:  =%##%-"
    echo -e "  #############  .*#%-.####:        "
    echo -e "  %%%%%%%%%%%%%.*####%=####:        "
    echo -e "             .*####%= .####:        "
    echo -e "           .*####%=   .####:        "
    echo -e "           +%##%=      ****:        "
    echo -e "\n"
}

setup_package_manager() {
    # Determine OS and Architecture
    OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
    VERSION=$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"')
    ARCH=$(uname -m)

    if [ "$ARCH" != "x86_64" ]; then
        echo -e "${ERROR} This script is intended for AMD64 (x86_64) architecture."
        echo -e " Your machine is running on $ARCH architecture, which is not supported."
        exit 1
    fi

    echo -e "${INFO} Detected OS: $OS, Version: $VERSION, Architecture: $ARCH"

    # Check for package manager and set commands accordingly
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt-get"
        PKG_UPDATE="sudo $PKG_MANAGER update >/dev/null"
        PKG_INSTALL="sudo $PKG_MANAGER install -y"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="sudo $PKG_MANAGER update -y >/dev/null"
        PKG_INSTALL="sudo $PKG_MANAGER install -y"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        PKG_UPDATE="sudo $PKG_MANAGER update -y >/dev/null"
        PKG_INSTALL="sudo $PKG_MANAGER install -y"
    else
        echo -e "${ERROR} Unsupported package manager. Exiting."
        exit 1
    fi

    echo -e "${INFO} Using package manager: $PKG_MANAGER"
}

display_eula() {

    # Display the welcome message
    echo "Welcome to the installation process for Daytona."
    echo -e "App version: $(display_version)\n"

    # Display the license agreement
    echo -e "${INFO} Before you can install Daytona, you must read and agree to the Non-Commercial License Agreement, which can be found at:"
    echo -e "📃 \e[1;34mhttps://www.daytona.io/eula\e[0m\n"

    # Prompt the user for acceptance (default is "yes" when Enter is pressed)
    read -r -p "Do you accept the terms of the license agreement? (yes/no) [yes]: " choice

    # Set the default value to "yes" if the user just presses Enter
    choice=${choice:-"yes"}
    # Convert the choice to lowercase
    choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    # Check the user's choice
    if [ "$choice_lower" = "yes" ] || [ "$choice_lower" = "y" ]; then
        echo -e "${OK} You have accepted the license agreement. Proceeding with the installation..."
    else
        echo -e "${ERROR} You have declined the license agreement. Installation aborted."
        exit 1
    fi
}

get_time() {
    local end_time elapsed_time hours minutes seconds
    end_time=$(date +%s)
    elapsed_time=$((end_time - start_time))

    # Convert the elapsed time to hours, minutes, and seconds
    hours=$((elapsed_time / 3600))
    minutes=$((elapsed_time % 3600 / 60))
    seconds=$((elapsed_time % 60))

    # Display the elapsed time in a human-readable format
    echo "${hours}h ${minutes}min ${seconds}s"
}

get_public_ip_address() {
    # Define an array of IP retrieval services in case some are blocked
    IP_SOURCES=("ifconfig.me" "whatismyip.akamai.com" "ipinfo.io/ip" "api.ipify.org")
    for source in "${IP_SOURCES[@]}"; do
        IP_ADDRESS=$(curl -s -4 "$source")
        if [ -n "$IP_ADDRESS" ]; then
            echo "$IP_ADDRESS"
            return
        fi
    done
}

# Check if the required variables are set
check_prereq() {

    check_and_prompt() {
        local var_name="$1"
        local prompt="$2"

        while [ -z "${!var_name}" ]; do
            read -r -p "$prompt" "${var_name?}"
        done
    }

    # Check if URL is set, if not, prompt for it
    check_and_prompt "URL" "Enter app hostname (valid domain) [FQDN]: "

    if [ -z "$URL" ]; then
        echo -e "\n${ERROR} URL variable is not set. Please set URL. Exiting..."
        exit 1
    else
        echo -e "${OK} URL variable is set."
    fi

    # Use certbot to get wildcard cert for your domain
    echo -e "${INFO} Checking wildcard certificate..."
    CERTIFICATE_FILE="/etc/letsencrypt/live/$URL/fullchain.pem"
    if sudo [ -f "$CERTIFICATE_FILE" ] &&
        sudo openssl x509 -checkend 0 -noout -in "$CERTIFICATE_FILE" >/dev/null &&
        sudo openssl x509 -noout -in "$CERTIFICATE_FILE" -ext subjectAltName | grep -q "DNS:$URL" &&
        sudo openssl x509 -noout -in "$CERTIFICATE_FILE" -ext subjectAltName | grep -q "DNS:*.$URL"; then
        echo -e "${OK} Certificate valid and matching $URL and *.$URL domains"
    else
        IP_ADDRESS=$(get_public_ip_address)
        echo -e "${INFO} For domain and TLS setup please add following A records and a TXT records generated by certbot"
        echo -e "  to your $URL DNS zone. First add TXT records so that you give some time for it"
        echo -e "  to propagate so certbot can validate your certificate."
        echo -e "\n$URL => $IP_ADDRESS"
        echo -e "*.$URL => $IP_ADDRESS\n"
        MAX_ATTEMPTS=5
        ATTEMPT=0
        while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            if sudo certbot certonly --manual --preferred-challenges=dns --register-unsafely-without-email \
                --server https://acme-v02.api.letsencrypt.org/directory --agree-tos \
                -d "*.$URL,$URL"; then
                echo -e "${OK} Certificate validated."
                break
            else
                ((ATTEMPT++)) # Increment the attempt counter
                echo -e "${ERROR} Certificate not validated. Retrying... Attempt $ATTEMPT of $MAX_ATTEMPTS."
                sleep 1
            fi
        done

        if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
            echo -e "${ERROR} Maximum attempts reached. Certificate not validated. Please repeat installation script. Exiting..."
            exit 1
        fi
    fi
}

wait_for_ingress_webhook() {
    echo -e "${INFO} Waiting for Ingress Nginx admission webhook to be ready..."
    local max_attempts=15
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if kubectl get validatingwebhookconfigurations ingress-nginx-admission &>/dev/null; then
            if kubectl get endpoints -n kube-system ingress-nginx-controller-admission &>/dev/null; then
                echo -e "${OK} Ingress Nginx admission webhook is ready."
                return 0
            fi
        fi
        echo -ne "Attempt $((attempt + 1))/$max_attempts - waiting...\r"
        attempt=$((attempt + 1))
        sleep 2
    done
    echo -e "${ERROR} Timed out waiting for Ingress Nginx admission webhook."
    return 1
}

# Check if helm release is installed. i - Need testing
check_helm_release() {
    local release_name="$1"
    local namespace="$2"

    # Check if the release is deployed
    status=$(helm status -n "$namespace" "$release_name" 2>/dev/null | awk '/STATUS:/{print $2}')

    if [[ "$status" != "deployed" ]]; then
        echo -e "${ERROR} The release $release_name is not deployed correctly."
        echo -e "${INFO} Please check for errors on the cluster related to $release_name."
        echo -e "${INFO} After addressing the problem, run './setup.sh --remove' first and then try the installation again."
        exit 1
    else
        echo -e "${OK} The release '$release_name' is deployed."
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install tools needed
# Install tools needed
check_commands() {
    # Determine the package manager
    if command_exists apt-get; then
        PKG_MANAGER="sudo apt-get"
        PKG_UPDATE="$PKG_MANAGER update >/dev/null"
        PKG_INSTALL="$PKG_MANAGER install -y"
    elif command_exists dnf; then
        PKG_MANAGER="sudo dnf"
        PKG_UPDATE="$PKG_MANAGER update -y >/dev/null"
        PKG_INSTALL="$PKG_MANAGER install -y"
    elif command_exists yum; then
        PKG_MANAGER="sudo yum"
        PKG_UPDATE="$PKG_MANAGER update -y >/dev/null"
        PKG_INSTALL="$PKG_MANAGER install -y"
    else
        echo "No compatible package manager found. Exiting."
        exit 1
    fi

    # Install curl
    if ! command_exists "curl"; then
        echo -e "${INFO} curl is not installed. Installing..."
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL" curl >/dev/null
        if curl --version &>/dev/null; then
            echo -e "${OK} curl is installed."
        fi
    fi

    # Install helm
    if ! command_exists "helm"; then
        echo -e "${INFO} helm is not installed. Installing..."
        curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null
        if helm version &>/dev/null; then
            echo -e "${OK} helm is installed."
        fi
    fi

    # Install certbot
    if ! command_exists "certbot"; then
        echo -e "${INFO} certbot is not installed. Installing..."
        eval "$PKG_UPDATE"
        eval "$PKG_INSTALL" certbot >/dev/null
        if certbot --version &>/dev/null; then
            echo -e "${OK} certbot is installed."
        fi
    fi
}

get_ingress_values() {

    cat <<EOF >ingress-values.yaml
controller:
  ingressClassByName: true
  hostNetwork: true
  hostPort:
    enabled: true
  service:
    type: ClusterIP
  updateStrategy:
    type: Recreate
EOF

}

get_longhorn_values() {

    cat <<EOF >longhorn-values.yaml
persistence:
  defaultClass: false
  defaultClassReplicaCount: 1
defaultSettings:
  priorityClass: system-node-critical
  deletingConfirmationFlag: true
  replicaSoftAntiAffinity: true
  storageOverProvisioningPercentage: 500
  defaultReplicaCount: 1
csi:
  attacherReplicaCount: 1
  provisionerReplicaCount: 1
  resizerReplicaCount: 1
  snapshotterReplicaCount: 1
longhornUI:
  replicas: 1
EOF

}

get_watkins_values() {

    cat <<EOF >watkins-values.yaml
image:
  registry: ghcr.io
  repository: daytonaio/workspace-service
namespaceOverride: "watkins"
fullnameOverride: "watkins"
configuration:
  defaultWorkspaceClass:
    cpu: 2
    gpu: ""
    memory: 8
    name: Default
    storage: 50
    usageMultiplier: 1
    runtimeClass: ""
    gpuResourceName: nvidia.com/gpu
  workspaceStorageClass: longhorn
  defaultPlanPinnedWorkspaces: 10
  defaultSubscriptionSeats: 10
  workspaceNamespace:
    name: watkins-workspaces
    create: true
ingress:
  enabled: true
  ingressClassName: "nginx"
  hostname: $URL
  annotations:
    nginx.ingress.kubernetes.io/proxy-buffer-size: 128k
  tls: true
  selfSigned: false
  extraTls:
    - hosts:
        - "*.$URL"
        - "$URL"
      secretName: "$URL-tls"
components:
  dashboard:
    namespace: watkins
    excludeJetbrainsCodeEditors: false
postgresql:
  enabled: true
rabbitmq:
  enabled: true
  nameOverride: "watkins-rabbitmq"
  persistence:
    enabled: true
  auth:
    username: user
    password: pass
    erlangCookie: "secreterlangcookie"
redis:
  enabled: true
  nameOverride: "watkins-redis"
  auth:
    enabled: false
  architecture: standalone
EOF

}

get_k3s_config() {
    sudo mkdir -p /etc/rancher/k3s
    sudo bash -c 'cat <<EOF > /etc/rancher/k3s/config.yaml
write-kubeconfig-mode: 644
disable:
  - traefik
  - servicelb
disable-helm-controller: true
cluster-init: false  # use sqlite instead embedded Etcd
node-label:
  - "daytona.io/node-role=workload"
EOF'

}

# Install k3s and setup kubeconfig
install_k3s() {

    # Install k3s using the official installation script
    get_k3s_config
    IP_ADDRESS=$(get_public_ip_address)
    echo -e "${INFO} Installing k3s..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" INSTALL_K3S_EXEC="--tls-san $IP_ADDRESS --tls-san $URL" sh - 2>&1 | grep -v "Created symlink" >/dev/null

    # Wait for k3s to be ready
    while ! sudo k3s kubectl get nodes &>/dev/null; do
        echo "Waiting for k3s to be ready..."
        sleep 5
    done
    mkdir -p "$HOME"/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml "$HOME"/.kube/config
    sudo chown "$USER:$USER" "$HOME"/.kube/config
    sudo chmod 700 "$HOME"/.kube/config
    echo -e "${OK} k3s is installed and running."
}

# Install supporting services and Watkins app
install_app() {

    # Setup iSCSI and longhorn
    kubectl create namespace longhorn-system --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    kubectl apply -n longhorn-system -f https://raw.githubusercontent.com/longhorn/longhorn/v${LONGHORN_VERSION}/deploy/prerequisite/longhorn-iscsi-installation.yaml >/dev/null
    echo -e "${OK} iSCSI installed."
    count=0
    while ! systemctl is-active iscsid &>/dev/null && ((++count <= 120)); do
        # Clear the line
        echo -ne "                                                            \r"
        case $((count % 3)) in
        0) echo -ne "${INFO} Checking if iscsid service is active.\r" ;;
        1) echo -ne "${INFO} Checking if iscsid service is active..\r" ;;
        2) echo -ne "${INFO} Checking if iscsid service is active...\r" ;;
        esac
        sleep 1
    done
    # Check if the service became active or exit with an error
    echo -ne "\r\e[K"
    if systemctl is-active iscsid &>/dev/null; then
        echo -e "${OK} iscsid service is active."
    else
        echo -e "${ERROR} iscsid service did not become active within 120 seconds. Please repeat installation script. Exiting..."
        exit 1
    fi

    # Check if multipathd service exists and is running
    if systemctl list-unit-files multipathd.service &>/dev/null; then
        echo -e "${OK} Multipathd service found, checking configuration."

        # Disable multipath
        blacklist_config="blacklist {
        devnode \"^sd[a-z0-9]+\"
    }"
        # Define the path to the multipath.conf file
        multipath_conf="/etc/multipath.conf"

        # Check if the blacklist configuration already exists in the file, if not add it and restart multipathd service
        if ! grep -q "$blacklist_config" "$multipath_conf"; then
            echo "$blacklist_config" | sudo tee -a "$multipath_conf" >/dev/null
            sudo systemctl restart multipathd.service
            echo -e "${OK} Blacklist configuration added to $multipath_conf."
        else
            echo -e "${OK} Blacklist configuration already exists in $multipath_conf."
        fi
    else
        echo -e "${OK} Multipathd service not found or not running."
    fi

    echo -e "${INFO} Installing longhorn helm chart"
    get_longhorn_values
    helm upgrade -i --create-namespace --version ${LONGHORN_VERSION} -n longhorn-system -f longhorn-values.yaml --repo https://charts.longhorn.io longhorn longhorn >/dev/null
    check_helm_release longhorn longhorn-system

    # Setup ingress-nginx
    echo -e "${INFO} Installing ingress-nginx helm chart"
    get_ingress_values
    helm upgrade -i --wait --timeout 5m --version ${INGRESS_NGINX_VERSION} -n kube-system -f ingress-values.yaml --repo https://kubernetes.github.io/ingress-nginx ingress-nginx ingress-nginx >/dev/null
    check_helm_release ingress-nginx kube-system

    # Wait for the Ingress Nginx admission webhook to be ready
    wait_for_ingress_webhook || exit 1

    # Create wildcard certificate secret to be used by ingress
    kubectl create namespace watkins --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    echo -e "${INFO} Creating wildcard certificate secret..."
    if sudo kubectl create secret tls -n watkins "${URL}"-tls --key=/etc/letsencrypt/live/"${URL}"/privkey.pem --cert=/etc/letsencrypt/live/"${URL}"/fullchain.pem --dry-run=client -o yaml | kubectl apply -f - >/dev/null; then
        echo -e "${OK} Creating wildcard certificate secret successful."
    else
        echo -e "${ERROR} Creating wildcard certificate secret failed."
        exit 1
    fi

    get_watkins_values
    if ! helm status -n watkins watkins >/dev/null 2>&1; then
        echo -e "${INFO} Installing watkins helm chart..."
    else
        echo -e "${INFO} Updating watkins helm chart..."
    fi
    helm upgrade -i --timeout 10m --version "${WATKINS_VERSION}" -n watkins \
        -f watkins-values.yaml watkins oci://ghcr.io/daytonaio/charts/watkins >/dev/null
    check_helm_release watkins watkins

    echo -e "${OK} k3s cluster and Watkins application installed in $(get_time)."
    echo -e "\n--------------------------------------------------------------------------------------------------\n"
    echo -e "${INFO} To access admin dashboard go to https://admin.${URL}"
    echo -e "\n--------------------------------------------------------------------------------------------------\n"
    echo -e "  Username: admin"
    echo -e "  Password: $(kubectl get secret -n watkins watkins -o=jsonpath='{.data.admin-password}' | base64 --decode)"
    echo -e "\n--------------------------------------------------------------------------------------------------\n"
    echo -e "${INFO} To access keycloak admin console go to https://id.${URL}"
    echo -e "  Username: admin"
    echo -e "  Password: $(kubectl get secret -n watkins watkins-watkins-keycloak -o=jsonpath='{.data.admin-password}' | base64 --decode)"
    echo -e "\n--------------------------------------------------------------------------------------------------\n"
    echo -e "${INFO} IMPORTANT: Obtaining a License"
    echo -e "To use Daytona Enterprise Demo, you need to obtain a license."
    echo -e "Please send a request to servicedesk@daytona.io to get your license."
    echo -e "Once you receive the license, you can apply it through the admin dashboard."
    echo -e "\n--------------------------------------------------------------------------------------------------\n"
    start_time=$(date +%s)
    echo -e "${INFO} You are advised to wait for preload operations to finish before you create your first workspace."
    echo -e "${INFO} Running preload operations so there is no wait time on initial workspace creation (will take ~20min)..."

    if sudo k3s ctr i ls | grep ghcr.io/daytonaio/workspace-service/workspace-image:"$(helm show chart oci://ghcr.io/daytonaio/charts/watkins --version "$WATKINS_VERSION" 2>/dev/null | grep 'appVersion:' | awk '{print $2}')" >/dev/null 2>&1; then
        echo -e "${OK} Watkins workspace container image exists."
    else
        echo -e "${INFO} Pulling watkins workspace container image..."
        sudo k3s ctr i pull ghcr.io/daytonaio/workspace-service/workspace-image:"$(helm show chart oci://ghcr.io/daytonaio/charts/watkins --version "$WATKINS_VERSION" 2>/dev/null | grep 'appVersion:' | awk '{print $2}')" >/dev/null
        echo -e "${OK} Watkins workspace container image pulled."
    fi

    while kubectl get pods -n watkins-workspaces --ignore-not-found=true | grep "pull-image" >/dev/null; do
        echo -ne "                                                            \r"
        echo -ne "${INFO} Waiting on watkins workspace storageClass preload.\r"
        sleep 1
        echo -ne "${INFO} Waiting on watkins workspace storageClass preload..\r"
        sleep 1
        echo -ne "${INFO} Waiting on watkins workspace storageClass preload...\r"
        sleep 1
    done
    echo -e "${OK} Watkins workspace storageClass preloaded."
    echo -e "${OK} Preload operations completed in $(get_time)."

    # Delete leftover resources
    rm -rf ingress-values.yaml \
        longhorn-values.yaml \
        watkins-values.yaml
}

# Function to uninstall k3s and remove longhorn data
uninstall() {
    # Uninstall k3s using the official uninstallation script
    if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
        /usr/local/bin/k3s-uninstall.sh
        echo -e "${OK} k3s has been uninstalled."
    else
        echo -e "${OK} k3s has not been found."
    fi

    for cmd in helm; do
        if command_exists $cmd; then
            sudo rm /usr/local/bin/$cmd
            echo -e "${OK} $cmd removed."
        fi
    done

    # Remove longhorn data
    if sudo rm -rf /var/lib/longhorn/*; then
        echo -e "${OK} Longhorn data has been removed."
    fi

    # Delete leftover resources
    rm -rf ingress-values.yaml \
        longhorn-values.yaml \
        watkins-values.yaml
}

display_version() {
    if command_exists "helm"; then
        version=$(helm show chart oci://ghcr.io/daytonaio/charts/watkins --version "$WATKINS_VERSION" 2>/dev/null | grep 'appVersion:' | awk '{print $2}')
    else
        # Read the version line from README.md. Suitable for first time installs
        version=$(grep -oP 'App_Version-\K[0-9]+\.[0-9]+\.[0-9]+' README.md)
    fi
    echo "$version"
}

# Display help message
display_help() {
    echo "Usage: $0 [--remove|--version|--help]"
    echo ""
    echo "Options:"
    echo "  --remove     Remove k3s."
    echo "  --version    Display app version to be installed."
    echo "  --help       Display this help message."
}

# Process the provided parameter
case "$1" in
--remove)
    uninstall
    ;;
--version)
    echo "Current app version: $(display_version)"
    ;;
--help)
    display_help
    ;;
*)
    if [ "$#" -gt 0 ]; then
        echo "Invalid parameter. Use --help to see the available options."
        display_help
        exit 1
    fi
    ;;
esac

# Default run
if [ "$#" -eq 0 ]; then
    display_logo
    display_eula
    setup_package_manager
    check_commands
    check_prereq
    install_k3s
    install_app
fi
