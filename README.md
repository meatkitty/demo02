helloworld
==========

Simple helloworld web application used to to demonstate continuiuos deployment into an openshift 3 cluster.

Release scripts for deployment to Nexus and Artifactory asset regsitries have been included.

```
helloworld
── assets							<< Maven configuration for deployment to assets regsitries
│   ├── pom.xml.artifcatory
│   ├── pom.xml.nexus
│   ├── release-to-registry.sh
│   ├── settings.xml.artifcatory
│   └── settings.xml.nexus
├── deploy
│   └── helloworld.war				<< Deployed web application archieve
├── Dockerfile						<< Docker container configuration
├── pom.xml							<< Maven project object model
├── README.md						
├── release.sh						<< Releases  code into scm and deploys to Openshift
├── src								
│   └── main
│       └── webapp
│           ├── index.jsp				<< Updated with the release timestamp
│           └── WEB-INF
│               └── web.xml
└── utils
    └── re-init						<< Re-initialisaiton of the git repo 
```

Instructions
------------

1. Clone this repository to a directory to a local direcory on your computer.
2. Modify the approrite variables in the release.sh script.
3. Login into the openshift cluster with the oc client.
4. Execute the release.sh script.
