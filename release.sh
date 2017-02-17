#!/bin/sh
#
# Copyright (C) 2017 Bluebank.
# Author: Salim Badakhchani <salim.badakhchani@bluebank.io>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
########################################################################


# Uncomment to enable debugging
#set -x 

# Declare variables
NAM="$(git config user.name)"			# SCM username
GIT="$(git config user.email)"  		# SCM email
USR="$(echo ${GIT/\@*})"				# Parse the name from the username
RID="$2"								# Take user input for repository identifier
DTE=$(date)								# Use the current date for a time stamp
SUB="bluebank.io"				        # Declare the subdomain for the PAAS
SCM="https://github.com" 			    # The SCM URL used to clone from 
APP="helloworld"						# Applicaiton name
PRO="${RID}-helloworld"					# Openshift environment
REP="${SCM}/${USR}/${APP}"				# SCM repository
OSD="kojapps.bluebank.io"               # Openshift cloudapps subdomain
SSH="id_rsa-bluebank"					# Public ssh key


# Usage options and user arguments
read -d '' USAGE <<- EOF
Usage: ./release.sh [options] <env>
-b, --build           build binary
-d, --deploy          deploy binary
-r, --release         build & deploy binary
-h, --help            prints this message

Example: ./release.sh -r <uid>
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
	cp -pf target/${APP}.war deploy/
    mvn clean

    # Commit the change to our local git repo
	git add -A && git commit -a -m "Version Update ${DTE}"
	git push origin master
}

deploy() {
    echo -e ">> Deploying binary to PAAS...\n"
    # Check for ssh agent
    [[ ! -z $(pgrep ssh-agent) ]] || eval "$(ssh-agent -s)" ; ssh-add $HOME/.ssh/${SSH}
    
    # Check if project exists
    PROJECTS="$(oc get projects)"

    for project in $PROJECTS; do
        if [ "$project" == "$PRO" ]; then
            oc delete project ${PRO} > /dev/null 2>&1
            until oc new-project ${PRO} > /dev/null 2>&1; do
                echo -e "Trying to reprovison project...Please be patient!"
                sleep 10
            done

		fi
    done 
    
    oc new-project ${PRO} > /dev/null 2>&1 
    oc new-app ${SCM}:${USR}/${APP}.git --name=${PRO}
    oc patch buildconfig ${PRO} -p '{"spec":{"source":{"sourceSecret":{"name":"sshsecret"}}}}'
    oc secrets new-sshauth sshsecret --ssh-privatekey=$HOME/.ssh/${SSH}
    oc secrets link builder sshsecret
    oc expose service/${PRO} --hostname=${PRO}.${OSD} --path=/${APP}
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

