<div align="center">

```
    ██╗ ██╗ ██╗
   ██╔╝████████╗
  ██╔╝ ╚██╔═██╔╝
 ██╔╝  ████████╗
██╔╝   ╚██╔═██╔╝
╚═╝     ╚═╝ ╚═╝
```
</div>

![Static Badge](https://img.shields.io/badge/APP_VERSION-8.83.2-blue)

## Requirements

Before starting the installation script, please go over all the necessary requirements.

### Host where the environment will be installed

* Host minimum hardware specification
    * x86_64 architecture Linux OS
    * min 4 vcpu
    * min 16GB RAM
    * min 200GB disk
* The host needs to have public IP and TCP ports 80, 443, and 30000 opened (also TCP 6443 if you want to access the Kubernetes cluster from your local machine)
* The script has been currently tested on Debian-based distros (Ubuntu 22.04/Ubuntu 23.04/Debian 12)

### Valid domain
Registered domain with base domain and wildcard pointed to your host IP where
* domain name IN A host.ip
* *.domain-name IN A host.ip

### OAuth App created with one of the Identity providers
One of the identity provider OAuth App set:
* [GitHub OAuth App](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/creating-an-oauth-app)
* [GitLab OAuth App](https://docs.gitlab.com/ee/integration/oauth_provider.html)
* [Bitbucket OAuth](https://support.atlassian.com/bitbucket-cloud/docs/use-oauth-on-bitbucket-cloud/)

Values to set in the identity provider:
* Homepage URL: https://{{ domain-name }}
* Authorization callback URL: https://id.{{ domain-name }}

## Setup

```
git clone https://github.com/daytonaio/installer
cd installer
./setup.sh
```

Here is the prompt you will receive if you choose Github IdP for example:
```
./setup.sh
...
Enter app hostname (valid domain) [FQDN]: daytona.example.com
Identity Providers (IdP) available [IDP]:
1) github
2) gitlab
3) bitbucket
4) gitlabSelfManaged
5) githubEnterpriseServer
Choose an IdP (type the number and press Enter): 1
Enter IdP Client ID [IDP_ID]: changeme
Enter IdP Client Secret (IDP_SECRET) (input hidden):
```

You will be prompted for the required values you need to set depending on the Identity provider chosen.

* `URL` - domain name you have set in your DNS provider and pointing to IP address of the machine where you are deploying Daytona
* `IDP` - name of identity provider to use (available are: github, gitlab and bitbucket)
* `IDP_URL` - (required if IDP is `gitlabSelfManaged` or `githubEnterpriseServer`) This is the base URL of your hosted Git provider.
* `IDP_API_URL` - (required if IDP is `githubEnterpriseServer`) This is the API URL of GitHub Enterprise Server.
* `IDP_ID` - client ID you get from your identity provider as stated in [Requirements](#requirements)
* `IDP_SECRET` - client secret you get from your identity provider as stated in [Requirements](#requirements)

Number of variables you need to set ranges from 4 to 6, depending on the Identity provider chosen. Here is a table showing IdP and variables you need:

<br>

| IdP     | variables needed     |
|--------------|--------------|
| github, gitlab, bitbucket | URL, IDP, IDP_ID, IDP_SECRET |
| gitlabSelfManaged | URL, IDP, IDP_ID, IDP_SECRET, IDP_URL |
| githubEnterpriseServer | URL, IDP, IDP_ID, IDP_SECRET, IDP_URL, IDP_API_URL |

<br>

It is also possible to set all values via CLI when running the script:
```
URL="daytona.example.com" IDP="github" IDP_ID="changeme" IDP_SECRET="changeme" ./setup.sh
```

Refer to the table above to see what variables you need to set.

After variables are set, the prompt will show you A records that need to be added to your DNS zone, and certbot will also show you information on how to edit your DNS zone in order to get a valid wildcard certificate, so please follow the instructions.

## Update

To update existing setup you simply need to run script again on the same machine. Be sure to download latest `setup.sh` and run it again:

```
./setup.sh
```

If you used prompt to provide any of the variables you will need to input those values again. Certificate setup, if still valid, will be skiped.

If you used CLI with those 3 values set, you can simply repeat that command:
```
URL="daytona.example.com" IDP_ID="changeme" IDP_SECRET="changeme" ./setup.sh
```

Note that if you will not be required to validate certificate if its still valid.

## Restart/Cleanup

If you want to remove and start all over, you can run the script with the `--remove` parameter, and it will delete k3s cluster with all the tools installed. Afterwards, you can create everything again with `--install`.

```
./setup.sh --remove
```
