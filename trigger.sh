#!/bin/bash
#
# Simple script to increment version in index.jsp and commit to scm to trigger a build

# Uncomment to enable debugging
#set -x 

DATE=$(date)
APP="helloworld"
SUB_DOMAIN="devops.bluebank.io"


# Update the version of the file
UPDATE=$(echo "<h3>Version Update ${DATE}</h3>")
sed -e "/\<h1>/a \ ${UPDATE}" src/main/webapp/index.jsp > update.jsp
cat update.jsp > src/main/webapp/index.jsp
rm update.jsp

# Run Build
mvn clean install
cp -pf target/${APP}.war deploy/
mvn clean

# Commit the change to our local git repo
git add -A && git commit -a -m "Version Update ${DATE}"
mvn clean install
git push origin master
