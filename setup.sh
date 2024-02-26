#!/bin/bash
set -e

export LC_ALL=en_US.UTF-8
export LC_CTYPE=UTF-8

start_time=$(date +%s)

OK="\033[1;32m✔\033[0m"
ERROR="\033[1;31m✘\033[0m"
INFO="\033[1;36mℹ\033[0m"

K3S_VERSION="v1.28.5+k3s1"
LONGHORN_VERSION="1.5.3"
INGRESS_NGINX_VERSION="4.8.3"
WATKINS_VERSION="2.91.2"
TEMPLATE_INDEX_URL="https://raw.githubusercontent.com/daytonaio/samples-index/main/index.json"

display_logo() {
    echo -e "\n"
    echo -e "    ██╗ ██╗ ██╗ "
    echo -e "   ██╔╝████████╗"
    echo -e "  ██╔╝ ╚██╔═██╔╝"
    echo -e " ██╔╝  ████████╗"
    echo -e "██╔╝   ╚██╔═██╔╝"
    echo -e "╚═╝     ╚═╝ ╚═╝ "
    echo -e "\n"
}

machine_arch=$(uname -m)

if [ "$machine_arch" != "x86_64" ]; then
    echo -e "${ERROR} This script is intended for AMD64 (x86_64) architecture."
    echo -e " Your machine is running on $machine_arch architecture, which is not supported."
    exit 1
fi

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

# Check if the required variables are set
check_prereq() {

    check_and_prompt() {
        local var_name="$1"
        local prompt="$2"

        if [ -z "${!var_name}" ]; then
            if [ "$var_name" == "IDP_SECRET" ]; then
                read -rs -p "$prompt" "${var_name?}"
            elif [ "$var_name" == "IDP" ]; then
                echo -e "$prompt"
                PS3="Choose an IdP (type the number and press Enter): "
                options=("github" "gitlab" "bitbucket" "gitlabSelfManaged" "githubEnterpriseServer")
                select opt in "${options[@]}"; do
                    case $REPLY in
                    1)
                        IDP="github"
                        break
                        ;;
                    2)
                        IDP="gitlab"
                        break
                        ;;
                    3)
                        IDP="bitbucket"
                        break
                        ;;
                    4)
                        IDP="gitlabSelfManaged"
                        break
                        ;;
                    5)
                        IDP="githubEnterpriseServer"
                        break
                        ;;
                    *) echo "Invalid option, please choose a number between 1 and 5." ;;
                    esac
                done
            else
                read -r -p "$prompt" "${var_name?}"
            fi
        fi

    }

    if [ -n "$IDP" ]; then
        supported_idps=("github" "gitlab" "bitbucket" "gitlabSelfManaged" "githubEnterpriseServer")
        is_supported=false

        for supported_idp in "${supported_idps[@]}"; do
            if [ "$supported_idp" = "$IDP" ]; then
                is_supported=true
                break
            fi
        done

        if $is_supported; then
            echo -e "${OK} Using IdP from CLI argument: $IDP"
        else
            echo -e "${ERROR} IdP not supported. You will be prompted to choose a supported one."
            unset IDP
        fi
    fi

    # Check again if any of the values are missing
    if [ -z "$URL" ] || [ -z "$IDP" ] || [ -z "$IDP_ID" ] || [ -z "$IDP_SECRET" ]; then
        echo -e "${INFO} Please check README on how to obtain values for required variables"
        echo -e "\e[1;34m  https://github.com/daytonaio/installer#requirements\e[0m\n"
        check_and_prompt "URL" "Enter app hostname (valid domain) [FQDN]: "
        check_and_prompt "IDP" "Identity Providers (IdP) available [IDP]: "
        if [ "$IDP" == "gitlabSelfManaged" ]; then
            check_and_prompt "IDP_URL" "Enter the base URL for GitLab self-managed [IDP_URL]: "
        fi
        if [ "$IDP" == "githubEnterpriseServer" ]; then
            check_and_prompt "IDP_URL" "Enter the base URL for GitHub Enterprise [IDP_URL]: "
            check_and_prompt "IDP_API_URL" "Enter the API URL for GitHub Enterprise [IDP_API_URL]: "
        fi
        check_and_prompt "IDP_ID" "Enter IdP Client ID [IDP_ID]: "
        check_and_prompt "IDP_SECRET" "Enter IdP Client Secret [IDP_SECRET] (input hidden): "
        #echo -e "\n"
    fi

    if [ -z "$URL" ] || [ -z "$IDP" ] || [ -z "$IDP_ID" ] || [ -z "$IDP_SECRET" ]; then
        echo -e "\n${ERROR} One or more of the required variables are not set. Please repeat installation script. Exiting..."
        exit 1
    elif [ "$IDP" == "gitlabSelfManaged" ] && [ -z "$IDP_URL" ]; then
        echo -e "\n${ERROR} IDP_URL is not set for gitlabSelfManaged. Please set IDP_URL. Exiting..."
        exit 1
    elif [ "$IDP" == "githubEnterpriseServer" ] && ([ -z "$IDP_URL" ] || [ -z "$IDP_API_URL" ]); then
        echo -e "\n${ERROR} IDP_URL and/or IDP_API_URL is not set for githubEnterpriseServer. Please set both. Exiting..."
        exit 1
    else
        echo -e "${OK} All required variables set."
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
        # Define an array of IP retrieval services in case some are blocked
        IP_SOURCES=("ifconfig.me" "whatismyip.akamai.com" "ipinfo.io/ip" "api.ipify.org")
        for source in "${IP_SOURCES[@]}"; do
            IP_ADDRESS=$(curl -s -4 "$source")
            if [ -n "$IP_ADDRESS" ]; then
                break
            fi
        done
        echo -e "${INFO} For domain and TLS setup please add following A records and a TXT records generated by certbot"
        echo -e "  to your $URL DNS zone. First add TXT records so that you give some time for it"
        echo -e "  to propagate so certbot can validate your certificate."
        echo -e "\n$URL => $IP_ADDRESS"
        echo -e "*.$URL => $IP_ADDRESS\n"
        MAX_ATTEMPTS=5
        ATTEMPT=0
        while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            if sudo certbot certonly --manual --preferred-challenges=dns --register-unsafely-without-email \
                --server https://acme-v02.api.letsencrypt.org/directory --agree-tos --manual-public-ip-logging-ok \
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

# Check if helm release is installed. i - Need testing
check_helm_release() {
    local release_name="$1"
    local namespace="$2"

    # Check if the release is deployed
    status=$(helm status -n "$namespace" "$release_name" 2>/dev/null | awk '/STATUS:/{print $2}')

    if [[ "$status" != "deployed" ]]; then
        echo -e "${ERROR} The release $release_name is not deployed. Please repeat installation script. Exiting..."
        helm delete -n "$namespace" "$release_name" --ignore-not-found
        if [[ "$release_name" == "watkins" && "$watkins_first_install" == "yes" ]]; then
            echo -e "${INFO} Removing watkins PVCs..."
            kubectl delete pvc --all -n "$namespace" --ignore-not-found >/dev/null
            exit 1
        fi
        exit 1
    fi

    if [[ "$calling_function" != "cleanup" ]]; then
        echo -e "${OK} The release '$release_name' is deployed."
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install tools needed
check_commands() {

    if ! command_exists "curl"; then
        echo -e "${INFO} curl is not installed. Installing..."
        sudo apt-get update >/dev/null
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl >/dev/null
        if curl --version &>/dev/null; then
            echo -e "${OK} curl is installed."
        fi
    fi

    if ! command_exists "helm"; then
        echo -e "${INFO} helm is not installed. Installing..."
        curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >/dev/null
        if helm version &>/dev/null; then
            echo -e "${OK} helm is installed."
        fi
    fi

    if ! command_exists "certbot"; then
        echo -e "${INFO} certbot is not installed. Installing..."
        sudo apt-get update >/dev/null
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y certbot >/dev/null
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
  defaultWorkspaceClassName: small
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
    workspaceTemplatesIndexUrl: $TEMPLATE_INDEX_URL
    namespace: watkins
    excludeJetbrainsCodeEditors: false
postgresql:
  enabled: true
gitProviders:
  $IDP:
    clientId: $IDP_ID
    clientSecret: $IDP_SECRET
    baseUrl: $IDP_URL
    apiUrl: $IDP_API_URL
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
EOF'

}

cleanup() {
    calling_function="cleanup"
    echo -e "${INFO} Cleaning up..."

    if [[ $1 != "--remove" ]]; then
        check_helm_release watkins watkins
    fi
    rm -rf ingress-values.yaml \
        longhorn-values.yaml \
        watkins-values.yaml
}

trap '[[ $1 != "--version" && $1 != "--help" ]] && cleanup "$1"' EXIT

# Install k3s and setup kubeconfig
install_k3s() {

    # Install k3s using the official installation script
    get_k3s_config
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh - 2>&1 | grep -v "Created symlink" >/dev/null

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
    while ! systemctl is-active iscsid &>/dev/null && ((++count <= 40)); do
        echo -ne "                                                            \r"
        echo -ne "${INFO} Checking if iscsid service is active.\r"
        sleep 1
        echo -ne "${INFO} Checking if iscsid service is active..\r"
        sleep 1
        echo -ne "${INFO} Checking if iscsid service is active...\r"
        sleep 1
    done
    # Check if the service became active or exit with an error
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
    helm upgrade -i --atomic --create-namespace --version ${LONGHORN_VERSION} -n longhorn-system -f longhorn-values.yaml --repo https://charts.longhorn.io longhorn longhorn >/dev/null
    check_helm_release longhorn longhorn-system

    # Setup ingress-nginx
    echo -e "${INFO} Installing ingress-nginx helm chart"
    get_ingress_values
    helm upgrade -i --atomic --version ${INGRESS_NGINX_VERSION} -n kube-system -f ingress-values.yaml --repo https://kubernetes.github.io/ingress-nginx ingress-nginx ingress-nginx >/dev/null
    check_helm_release ingress-nginx kube-system

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
        watkins_first_install="yes"
        echo -e "${INFO} Installing watkins helm chart..."
    else
        watkins_first_install="no"
        echo -e "${INFO} Updating watkins helm chart..."
    fi
    helm upgrade -i --atomic --timeout 10m --version "${WATKINS_VERSION}" -n watkins \
        -f watkins-values.yaml watkins oci://ghcr.io/daytonaio/charts/watkins >/dev/null
    check_helm_release watkins watkins

    echo -e "${OK} k3s cluster and Watkins application installed in $(get_time)."
    echo -e "\n--------------------------------------------------------------------------------------------------\n"
    echo -e "${INFO} To access dashboard go to https://${URL}"
    echo -e "\n--------------------------------------------------------------------------------------------------\n"
    echo -e "${INFO} To access keycloak admin console go to https://id.${URL}"
    echo -e "  Username: admin"
    echo -e "  Password: $(kubectl get secret -n watkins watkins-watkins-keycloak -o=jsonpath='{.data.admin-password}' | base64 --decode)"
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

    while kubectl get pods -n watkins --ignore-not-found=true | grep "pull-image" >/dev/null; do
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
}

display_version() {
    if command_exists "helm"; then
        version=$(helm show chart oci://ghcr.io/daytonaio/charts/watkins --version "$WATKINS_VERSION" 2>/dev/null | grep 'appVersion:' | awk '{print $2}')
    else
        # Read the version line from README.md. Suitable for first time installs
        version=$(grep -oP 'APP_VERSION-\K[0-9]+\.[0-9]+\.[0-9]+' README.md)
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
    display_logo
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
    check_commands
    check_prereq
    install_k3s
    install_app
fi
