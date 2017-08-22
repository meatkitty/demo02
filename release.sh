#!/bin/bash
#set -ex 

REG="docker-registry-default.bluebank.io:443"
USR="$2"
PRO="$3"
ENV="$4"
REP="${USR}-${PRO}-${ENV}"
IMG="helloworld"
TAG="latest"
DTE=$(date)

# Usage options and user arguments
read -d '' USAGE <<- EOF
Usage: ./release.sh [options] <usr> <pro> <env>
-b, --build           build binary
-d, --deploy          deploy binary
-r, --release         build & deploy binary
-h, --help            prints this message

Example: ./release.sh -r my-user my-project my-env
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
    echo -e "\n# Building binary for ${REP}..."
    
    echo -e "\n# Sync with upstream..."
    git pull 
    
    echo -e "\n# Update the version of the file..."
    echo "<h3>Hello World!!! - Bluebank PAAS - DevOps Circuit - Version Update >> ${DTE}</h3>" > ./src/main/webapp/index.jsp
    
    echo -e "\n# Run Build"
    mvn clean install
    cp -pf target/${IMG}.war deploy/
    mvn clean
    
    echo -e "\n# Commit the change to our local git repo..."
    git add -A && git commit -a -m "Version Update ${DTE}"
    git push origin master
}

deploy() {
    echo -e "\n# Deploying binary to OCP for ${REP}..."

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

    echo -e "\n# Login to registry..."
    docker login --username=$(oc whoami) --password=$(oc whoami -t) ${REG}

    echo -e "\n# build an tag image..."
    docker build -t ${REG}/${REP}/${IMG}:${TAG} .

    echo -e "\n# Push image..."
    docker push ${REG}/${REP}/${IMG}:${TAG}

    echo -e "\n# Deploy application..."
    oc new-app helloworld
    oc delete service helloworld
    oc create service nodeport helloworld --tcp=443:8080
    oc create route edge --hostname=helloworld.bluebank.io --service=helloworld --path=/helloworld --port=8080 --insecure-policy=Redirect
}


if [[ ! $# < 4 ]]; then echo "${USAGE}"; fi
while [[ ! $# > 4 ]]; do OPTS="$1"; shift

case $OPTS in
    -b|--build)
    build
    shift
    ;;
    -d|--deploy)
    deploy
    shift
    ;;
    -r|--release)
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
