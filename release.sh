#!/bin/bash
#set -ex 

REG="docker-registry-default.bluebank.io:443"
REP="sb-helloworld-dev"
IMG="helloworld"
TAG="latest"
DTE=$(date)

# Usage options and user arguments
read -d '' USAGE <<- EOF
Usage: ./release.sh [options] <env>
-b, --build           build binary
-d, --deploy          deploy binary
-r, --release         build & deploy binary
-h, --help            prints this message

Example: ./release.sh -r <project-name>
EOF

# Cache scm credentials for convenience
git config credential.helper "cache --timeout=3600" 

# Run pre-execution tests
if [[ ${EUID} -eq 0 ]]; then 
    echo "Please don't execute this script as root user!"
    exit 1
fi

# Define core functions
build() {
    echo -e ">> Building binary...\n"
    
    # Sync with upstream
	git pull 

    # Update the version of the file
	echo "<h3>Hello World!!! - Bluebank PAAS - DevOps Circuit - Version Update >> ${DTE}</h3>" > ./src/main/webapp/index.jsp

    # Run Build
	mvn clean install
	cp -pf target/${IMG}.war deploy/
        mvn clean

    # Commit the change to our local git repo
	git add -A && git commit -a -m "Version Update ${DTE}"
	git push origin master
}

deploy() {
    echo -e ">> Deploying binary to PAAS...\n"

    # Check if project exists
    PROJECTS="$(oc get projects)"

    for project in $PROJECTS; do
        if [ "$project" == "$REP" ]; then
            oc delete project ${REP} > /dev/null 2>&1
            until oc new-project ${REP} > /dev/null 2>&1; do
            echo -e "Trying to reprovison project...Please be patient!"
            sleep 10
            done
        fi
    done

    echo -e "\n# Create project"
    oc new-project ${REP}

    echo -e "\n# Login to registry..."
    docker login --username=$(oc whoami) --password=$(oc whoami -t) ${REG}

    echo -e "\n# build an tag image..."
    docker build -t ${REG}/${REP}/${IMG}:${TAG} .

    echo -e "\n# Push image..."
    docker push ${REG}/${REP}/${IMG}:${TAG}

    echo -e "\n# Deploy application..."
    oc new-app helloworld
    oc create route edge --hostname=helloworld.bluebank.io --service=helloworld --port=8080 --insecure-policy=Redirect
    break
}


if [[ $# < 1 ]]; then echo "${USAGE}"; fi
while [[ $# > 0 ]]; do OPTS="$1"; shift

case $OPTS in
    -b|--build)
    echo -e "Executing build..."
    build
    shift
    ;;
    -d|--deploy)
    echo -e "Deploying build..."
    deploy
    shift
    ;;
    -r|--release)
    echo -e "Releasing build..."
    build
    deploy
    shift
    ;;
    -h|--help)
    echo "${USAGE}"
    shift
    ;;
    *)
    echo "${USAGE}" # unknown option
    ;;
    \?)
    echo "${USAGE} option" # unknown option
    ;;
esac
done
