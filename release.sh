#!/bin/bash
#
# Simple script to increment version in demo

# Uncomment to enable debugging
#set -x 

DTE=$(date)
SCM="https://github.com"
USR="sbadakhc"
APP="helloworld"
REP="${SCM}/${USR}/${APP}"
REG="gitlab.bluebank.io:4678/${USR}/${APP}"
SUB_DOMAIN="devops.bluebank.io"

read -d '' USAGE <<- EOF
Usage: kojak [options] deploy
-b, --byob            bring your own container
-c, --byoc            bring your own binary
EOF


if [[ $# < 1 ]]; then echo "${USAGE}"; fi
while [[ $# > 1 ]]; do OPTS="$1"; shift

case $OPTS in
    -b|--byob)
    echo -e "Deploying binary to the cloud..."
    echo
    while true; do
        read -p ">> Triggering a release will rebuild your environment from scratch...Do you want to continue? [Y/n]" OPTS
            case $OPTS in
                [Yy]* ) echo -e "\n>> Pushing changes upstream"
                        # Delete current project
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
                                    echo -e "\n>> Creating project ${APP}" && oc new-project ${APP}
                                    echo -e "\n>> Creating app ${APP}" && oc new-app ${REP}.git --name=${APP}
                                    echo -e "\n>> Creating Service and Route" &&  oc expose service/helloworld --hostname=${APP}.${SUB_DOMAIN} --path=/${APP}
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
                    echo -e "\n>> Deleting project" && oc delete project ${APP} && sleep 5
                    echo -e "\n>> Creating new project" && oc new-project ${APP} 
                    echo -e "\n>> Creating app" && oc new-app --insecure-registry ${REG}:latest --name=${APP}
                    echo -e "\n>> Creating Service and Route" &&  oc expose service/helloworld --hostname=${APP}.${SUB_DOMAIN} --path=/${APP}
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

