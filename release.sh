#!/bin/bash
#
# Simple script to increment version in demo

# Uncomment to enable debugging
#set -x 

# Modify environemtn varibles accordingly
DTE=$(date)
SCM="https://github.com"
GRP="devcops"
APP="helloworld"
REP="${SCM}/${GRP}/${APP}"
REG="gitlab.bluebank.io:4678/${GRP}/${APP}"
SUB="devops.bluebank.io"
USR="Salim Badakhchani"
MBX="sbadakhc@gmail.com"

read -d '' USAGE <<- EOF
Usage: kojak [options] deploy
-b, --byob            bring your own container
-c, --byoc            bring your own binary
EOF

git config credential.helper "cache --timeout=3600" 
git config user.name "${USR}"
git config user.email "${MBX}"

if [[ $# < 1 ]]; then echo "${USAGE}"; fi
while [[ $# > 1 ]]; do OPTS="$1"; shift

case $OPTS in
    -b|--byob)
    echo -e "Deploying binary to the cloud..."
    echo
    while true; do
        read -p ">> Triggering a release will rebuild your environment from scratch...Do you want to continue? [Y/n]" OPTS
            case $OPTS in
                [Yy]* ) echo -e "\n>> Synchronising project..."
                        oc delete project ${APP}
                        sleep 5 

                        # Sync with upstream
                        git pull

                        # Update the version of the file
                        UPDATE=$(echo "<h3>Version Update ${DTE}</h3>")
                        sed -e "/\<h1>/a \ ${UPDATE}" src/main/webapp/index.jsp > update.jsp
                        cat update.jsp > src/main/webapp/index.jsp
                        rm update.jsp

                        # Run Build
                        mvn clean install
                        cp -pf target/${APP}.war deploy/
                        mvn clean

                        # Commit the change to our local git repo
                        git add -A && git commit -a -m "Version Update ${DTE}"

                        # Prompt for release
                        echo
                        while true; do
                            read -p ">> Do you want release this version? [Y/n]" OPTS
                                case $OPTS in
                                    [Yy]* ) echo -e "\n>> Pushing changes upstream"  
                                    mvn clean install
                                    git push origin master
                                    oc new-project ${APP}
                                    oc new-app ${REP}.git --name=${APP}
                                    oc expose service/helloworld --hostname=${APP}.${SUB} --path=/${APP}
                                    exit ;;
                                    [Nn]* ) echo -e "\n>> Release aborted" && exit ;;
                                    * ) echo ">> Invalid Option";;
                                esac
                        done
                [Nn]* echo -e "\n>> Release aborted" && exit ;;
                * ) echo ">> Invalid Option";;
            esac
    done
    shift
    ;;
    -c|--byoc)
    echo -e "Deploying container to the cloud..."
    echo
    while true; do
        read -p ">> Triggering a release will rebuild your environment from scratch...Do you want to continue? [Y/n]" OPTS
            case $OPTS in
                [Yy]* ) echo -e "\n>> Deploying container to ${APP}"
                    docker login gitlab.bluebank.io:4678
                    docker build -t gitlab.bluebank.io:4678/devcops/${APP} .
                    docker push gitlab.bluebank.io:4678/devcops/${APP}
                    oc delete project ${APP} && sleep 5
                    oc new-project ${APP} 
                    oc new-app --insecure-registry=true --docker-image="gitlab.bluebank.io:4678/devcops/helloworld":latest --name=${APP}
                    echo -e "\n>> Creating Service and Route" &&  oc expose service/helloworld --hostname=${APP}.${SUB} --path=/${APP}
                    exit ;;
                [Nn]* ) echo -e "\n>> Release aborted" && exit ;;
                * ) echo ">> Invalid Option";;
            esac
    done
    shift
    ;;
    -h|--help)
    echo "Help options include"
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
