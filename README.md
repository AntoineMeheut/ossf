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
	* [Feedback](#feedback)
* [Gitlab-ce](#xxx)

* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Contact](#contact)
* [Acknowledgements](#acknowledgements)

<!-- ABOUT THE PROJECT -->
# About this project
## My goals
xxx
## Features
xxx
## Feedback
xxx




<!-- SOFTWARE FACTORY INSTALLATION -->
Gitlab CI
1- Mettre à jour votre instance ubuntu
sudo apt update && sudo apt upgrade -y

2- Définir l’url et le password admin de votre instance gitlab-ce
export EXTERNAL_URL=https://gitlab.ame.tech
export GITLAB_ROOT_PASSWORD=gitlab

3- Installer les dépendances de gitlab-ce
sudo apt-get install -y curl openssh-server ca-certificates tzdata perl postfix

4- Faire le lien avec l’image gitlab-ce
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash

5- Installer gitlab-ce
sudo apt-get install gitlab-ce

6- Fixer la version de gitlab-ce
sudo apt-mark hold gitlab-ce

7- Vérifier la version fixée
sudo apt-mark showhold

8- Configurer gitlab-ce
sudo nano /etc/gitlab/gitlab.rb

9- Intégrer votre configuration à gitlab-ce
sudo gitlab-ctl reconfigure

https://docs.gitlab.com/ci/quick_start/
Gitlab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt install gitlab-runner
Gitleaks
https://blog.stephane-robert.info/docs/securiser/analyser-code/gitleaks/
https://gitlab.com/to-be-continuous/gitleaks
Owasp dependency check
https://gitlab.com/gitlab-ci-utils/docker-dependency-check
https://jdriven.com/blog/2022/07/OWASP-dependency-check-on-GitLab-com
Sonarqube
https://medium.com/@alishayb/quality-assurance-using-sonarqube-gitlab-sonarqube-integration-f6ae61bc49f4
https://blog.searce.com/diving-into-seamless-code-quality-unleashing-the-power-of-sonarqube-in-gitlab-pipeline-46573ee435b0
Horusec
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

