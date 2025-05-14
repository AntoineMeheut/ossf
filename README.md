<p align="center">
    <img src="https://socialify.git.ci/AntoineMeheut/ossf/image?custom_description=Open+Source+Software+Factory+%21&description=1&language=1&name=1&pattern=Circuit+Board&theme=Dark" alt="AntoineMeheut" width="700" height="300" />
</p>

<!-- PROJECT SHIELDS -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![GNU License][license-shield]][license-url]

<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="https://github.com/AntoineMeheut/ossf">
    <img src="images/ci-cd.png" alt="Software Factory" width="250" height="150">
  </a>

  <h3 align="center">Open Source Software Factory</h3>

  <p align="center">
    Principles, approach and installation of an open source software factory, to improve the quality and security of the code produced by a development team..
    <br />
    <a href="https://github.com/AntoineMeheut/blogame/issues">Report Bug</a>
    ·
    <a href="https://github.com/AntoineMeheut/blogame/projects">Request Feature</a>
  </p>
</p>

<!-- TABLE OF CONTENTS -->
# Table of Contents

* [About the Project](#about-the-project)
	* [My goals](#my-goals)
	* [Features](#features)
	* [Prerequisites](#prerequisites)
* [Gitlab CE & Runner installation](#gitlab-CE-&-Runner-installation)
* [Sonarqube installation](#sonarqube-installation)
* 
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Contact](#contact)
* [Acknowledgements](#acknowledgements)

<!-- ABOUT THE PROJECT -->
# About this project
## My goals
By working in various startups and small development teams, I realized that these teams often lack the minimum tools to improve the quality and security of their developments. The desire to do better is very real, and only time and knowledge are holding them back.

## Features
In this repository, I propose an approach to quickly set up and use a software factory built on open source tools. The proposed architecture is very simple and not ready for production. But it will allow you to analyze and improve code very quickly. I use this architecture to conduct my own code audits. This allows me to very quickly identify areas in the code where I will spend time digging and understanding.

This software factory is therefore built on:
- a secrets search tool,
- a tool for searching for security vulnerabilities in imported dependencies,
- a static code security analysis tool,
- a code quality analysis tool,
- and finally, a mechanism that allows you to obtain a complete analysis report in PDF format.

## Prerequisites
This software factory is built on two virtual machines with an Ubuntu 22.04 server-type OS.

The first machine contains:
- Gitlab-ce to load the code to be analyzed,
- Gitlab Runner to use pipelines to orchestrate code analysis,
- Owasp dependency check for analyzing imported dependencies,
- and Horusec for static code security analysis.

The second machine contains:
- Sonarqube for code quality and security analysis.

Everything is orchestrated by pipelines in Gitlab.

<!-- SOFTWARE FACTORY INSTALLATION -->
## Gitlab CE & Runner installation
### Use the following script and commands
```shell
wget -O ~/gitlab-ubuntu-server-20.04.sh https://raw.githubusercontent.com/AntoineMeheut/ossf/refs/heads/main/install-gitlab-ce/gitlab-ubuntu-server-20.04.sh
```

```shell
sudo bash ~/gitlab-ubuntu-server-20.04.sh -d gitlab.ame.tech
```
## Sonarqube installation
### Use the following script and commands
```shell
#TODO
```

```shell

```


## Upload a project to your Gitlab
https://docs.gitlab.com/ci/quick_start/

## Gitleaks
https://blog.stephane-robert.info/docs/securiser/analyser-code/gitleaks/
https://gitlab.com/to-be-continuous/gitleaks

## Owasp dependency check
https://gitlab.com/gitlab-ci-utils/docker-dependency-check
https://jdriven.com/blog/2022/07/OWASP-dependency-check-on-GitLab-com

## Sonarqube
https://medium.com/@alishayb/quality-assurance-using-sonarqube-gitlab-sonarqube-integration-f6ae61bc49f4
https://blog.searce.com/diving-into-seamless-code-quality-unleashing-the-power-of-sonarqube-in-gitlab-pipeline-46573ee435b0

## Horusec
https://gitlab.com/tanuki-workshops/kube-demos/vulnerability-demo-projects/kotlin-horusec-demo/-/blob/master/.gitlab-ci.yml
https://git.paytvlabs.com.br/devops/gitlab-ci/-/blob/2a2700c3cccb6b6d0042c3c88dde373618fbcb18/horusec.yml

<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create.
Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE` for more information.

<!-- CONTACT -->
## Contact

If you want to contact me [just clic](mailto:github.contacts@protonmail.com)

Project Link: [https://github.com/AntoineMeheut/ossf](https://github.com/AntoineMeheut/ossf)

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/AntoineMeheut/ossf?color=green
[contributors-url]: https://github.com/AntoineMeheut/ossf/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/AntoineMeheut/ossf
[forks-url]: https://github.com/AntoineMeheut/ossf/network/members
[stars-shield]: https://img.shields.io/github/stars/AntoineMeheut/ossf
[stars-url]: https://github.com/AntoineMeheut/ossf/stargazers
[issues-shield]: https://img.shields.io/github/issues/AntoineMeheut/ossf
[issues-url]: https://github.com/AntoineMeheut/ossf/issues
[license-shield]: https://img.shields.io/github/license/AntoineMeheut/ossf
[license-url]: https://github.com/AntoineMeheut/ossf/blob/master/LICENSE

