<div align="center">
	<picture>
		<source media="(prefers-color-scheme: dark)" srcset="https://github.com/daytonaio/daytona/raw/main/assets/images/Daytona-logotype-white.png">
		<img alt="Daytona logo" src="https://github.com/daytonaio/daytona/raw/main/assets/images/Daytona-logotype-black.png" width="40%">
	</picture>
</div>

<br><br>

<div align="center">

[![License](https://img.shields.io/badge/License-Elastic--2.0-blue)](#license)
[![Issues - daytona](https://img.shields.io/github/issues/daytonaio/enterprise-demo)](https://github.com/daytonaio/enterprise-demo/issues)
![Static Badge](https://img.shields.io/badge/App_Version-8.106.1-blue)

</div>

<h1 align="center">Daytona Enterprise Demo</h1>
<div align="center">
Try out a demo version of Daytona Enterprise on a single-node.
</div>
</br>

<p align="center">
    <a href="https://github.com/daytonaio/enterprise-demo/issues/new?assignees=&labels=bug&projects=&template=bug_report.md&title=%F0%9F%90%9B+Bug+Report%3A+">Report Bug</a>
    ·
    <a href="https://github.com/daytonaio/enterprise-demo/issues/new?assignees=&labels=enhancement&projects=&template=feature_request.md&title=%F0%9F%9A%80+Feature%3A+">Request Feature</a>
    ·
  <a href="https://join.slack.com/t/daytonacommunity/shared_invite/zt-273yohksh-Q5YSB5V7tnQzX2RoTARr7Q">Join Our Slack</a>
    ·
    <a href="https://twitter.com/daytonaio">Twitter</a>
  </p>

<hr/>

## What is the Daytona Enterprise Demo?
The Daytona Enterprise Demo is a resource limited, single-node deployment of Daytona's enterprise offering.
This allows you to experience the capabilities of Daytona Enterprise, demonstrating how it can streamline Development Environment Management (DEM) within your organization.

> [!IMPORTANT]
> __The information in this repository does not apply to the Daytona open source project.__  Please refer to [`daytonaio/daytona`](https://github.com/daytonaio/daytona) for information on setting up the Daytona open source project.

> [!IMPORTANT]
> After the installation and setup process is complete, you will need a license to use Daytona Enterprise Demo. Currently, you can obtain a license by sending a request to servicedesk@daytona.io.

## Getting Started

### Requirements
* An x86_64 Linux host operating system with minimum specs:
    * 4-core CPU
    * 16GB RAM
    * 250GB disk
* Accessible TCP ports 80, 443, and 30000
* A registered domain with the following DNS records:
    * `<domain> IN A host.ip`
    * `*.<domain> IN A host.ip`
* An OAuth application with a supported identity provider (GitHub, GitLab, Bitbucket) configured with the following values:
    * __Homepage URL:__ `https://<domain>`
    * __Authorization callback URL:__ `https://id.<domain>`

> [!NOTE]
> The deployment script has been officially tested on:
> * Ubuntu 22.04, Ubuntu 23.04
> * Debian 12
> * Fedora 40
>
> If you need access to the Kubernetes cluster, ensure TCP port 6443 is open.

> [!TIP]
> For information on setting up an OAuth application, visit the corresponding documentation for your provider:
> * [GitHub OAuth documentation](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/creating-an-oauth-app)
> * [GitLab OAuth documentation](https://docs.gitlab.com/ee/integration/oauth_provider.html)
> * [Bitbucket OAuth documentation](https://support.atlassian.com/bitbucket-cloud/docs/use-oauth-on-bitbucket-cloud/)

### Tools Installed
The setup script installs the following tools/packages on your host:

- **K3s**: A lightweight Kubernetes distribution
- **kubectl**: Command-line tool for interacting with Kubernetes clusters (included with K3s)
- **Helm**: The package manager for Kubernetes
- **jq**: Command-line JSON processor
- **curl**: Command-line tool for transferring data using various protocols

### Deployment
You can deploy Daytona Enterprise Demo either by using the guided method or by setting the URL environment variable.

#### Guided Deployment
1. Clone this repository to the host machine and run the script:
    ```console
    git clone https://github.com/daytonaio/enterprise-demo
    cd enterprise-demo
    ./setup.sh
    ```
#### Using Environment Variables
1. Clone this repository to the host machine and run the script by setting the URL directly:
     ```console
     git clone https://github.com/daytonaio/enterprise-demo
     cd enterprise-demo
     URL="daytona.example.com" ./setup.sh
     ```

2. Follow the instructions output by the script to configure required DNS records.

### Updating
You can update an existing deployment of Daytona Enterprise Demo.

1. In your clone of this repository, execute the following to incorporate the latest updates:
    ```
    git pull origin
    ```
2. Follow either the [Guided Deployment](#guided-deployment) or [Using Environment Variables](#using-environment-variables) procedure using the same variables.

### Removing/Uninstalling
You can remove a deployed version of Daytona Enterprise Demo from the host machine.
This procedure allows you to redeploy the demo from scratch using the [Guided Deployment](#guided-deployment) or [Using Environment Variables](#using-environment-variables) procedure. It's also useful to reset your host machine to it's previous state before deployment.

* In your clone of this repository, run:
    ```console
    ./setup.sh --remove
    ```

### Environment Variable Reference

| Environment variable | Required? | Description |
| -------------------- | --------- | ----------- |
| `URL` | Yes | The domain name (`<domain>`) used to access Daytona. |


## Contributing
Daytona is licensed under the [Elastic License 2.0](LICENSE). If you would like to contribute to the software, you must:

1. Read the Developer Certificate of Origin Version 1.1 (https://developercertificate.org/)
2. Sign all commits to the Daytona project.

This ensures that users, distributors, and other contributors can rely on all the software related to Daytona being contributed under the terms of the [License](LICENSE). No contributions will be accepted without following this process.

## License
This repository contains the Daytona Enterprise Demo installer, covered under the [Elastic License 2.0](LICENSE.txt), except where noted (any Daytona logos or trademarks are not covered under the Elastic License, and should be explicitly noted by a LICENSE file.)

Others are allowed to make their own distribution of the software in this repository under the license, but they cannot use any of the Daytona trademarks, cloud services, etc.

We explicitly grant permission for you to make a build that includes our trademarks while developing Daytona itself. You may not publish or share the build, and you may not use that build to run Daytona for any other purpose.

## Code of Conduct
This project has adapted the Code of Conduct from the [Contributor Covenant](https://www.contributor-covenant.org/). For more information see the [Code of Conduct](CODE_OF_CONDUCT.md) or contact [codeofconduct@daytona.io.](mailto:codeofconduct@daytona.io) with any additional questions or comments.

## Questions
For more information on how to use and develop Daytona, talk to us on
[Slack](https://join.slack.com/t/daytonacommunity/shared_invite/zt-273yohksh-Q5YSB5V7tnQzX2RoTARr7Q).
