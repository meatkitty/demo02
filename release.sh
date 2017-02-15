#!/bin/bash
#
# Simple script to increment version in demo

# Uncomment to enable debugging
set -x 

# Modify environemtn varibles accordingly
DTE=$(date)
SCM="https://github.com"
USR="sbadakhc"
APP="helloworld"
REP="${SCM}/${USR}/${APP}"
REG="gitlab.bluebank.io:4678/${GRP}/${APP}"
SUB="kojapps.bluebank.io"
NAM="Salim Badakhchani"
MBX="sbadakhc@gmail.com"

git config credential.helper "cache --timeout=3600" 
git config user.name "${NAM}"
git config user.email "${MBX}"

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

git push origin master
oc new-project ${APP}
oc new-app --name=${APP}:latest
oc expose service/${APP} --hostname=${APP}.${SUB} --path=/${APP}
