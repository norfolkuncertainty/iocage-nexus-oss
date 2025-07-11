#!/bin/sh
# Rebasing XYZ :: Nexus OSS TrueNAS Plugin
# 
# Post install script, this script will>
# - Download and copy the Nexus binary to its final location
# - Unpack the file and remove the tar.gz file
# - Create tne Nexus user
# - Update the ownership on /home/nexus to the nexus user
#
#
##########################################################
# Local Envs
# Default username
USER="nexus"

# Binary name
BIN_NAME="nexus-oss.tar.gz"
NEXUS_VERSION="3.78.1-02"

##########################################################
# Add nexus user
pw add user -n ${USER} -c NexusOSS -s /bin/sh -m

##########################################################
# Download and install Nexus
fetch -o /home/${USER}/${BIN_NAME} https://sonatype-download.global.ssl.fastly.net/repository/downloads-prod-group/3/nexus-unix-x86-64-${NEXUS_VERSION}.tar.gz
cd /home/${USER} && tar -xzvf ${BIN_NAME}

# remove the binary to save space
rm -rfv ${BIN_NAME}

# replace the nexus.vmoptions and nexus files
fetch -o /home/${USER}/nexus-${NEXUS_VERSION}/bin/nexus https://raw.githubusercontent.com/norfolkuncertainty/iocage-nexus-oss/main/bin/nexus
fetch -o /home/${USER}/nexus-${NEXUS_VERSION}/bin/nexus.vmoptions https://raw.githubusercontent.com/norfolkuncertainty/iocage-nexus-oss/main/bin/nexus.vmoptions
fetch -o /home/${USER}/nexus-${NEXUS_VERSION}/bin/nexus-rc.sh https://raw.githubusercontent.com/norfolkuncertainty/iocage-nexus-oss/main/bin/nexus-rc.sh

echo "Applying execution permission on /home/${USER}/nexus-${NEXUS_VERSION}/bin/nexus \n"
chmod +x /home/${USER}/nexus-${NEXUS_VERSION}/bin/nexus

# update ownership on nexus home
echo "Updating user permission for ${USER} /home/${USER} \d"
chown -R ${USER}:${USER} /home/${USER}

##########################################################
# Defines JAVA_HOME env
export JAVA_HOME="/usr/local/openjdk17"

##########################################################
# Prepare nexus to run as a service
cp /home/${USER}/nexus-${NEXUS_VERSION}/bin/nexus-rc.sh /etc/rc.d/nexus
chmod 555 /etc/rc.d/nexus

sysrc -f /etc/rc.conf nexus_enable="YES"
sysrc nexus_user=${USER}

echo -n "Starting Nexus OSS...\n"
service nexus start 2>/dev/null

status=null
while [ "${status}" != "running" ]; do
    fetch -s http://localhost:8081
    if [ $? == 0 ]; then
        echo "Seems that Nexus is ready."
        status="running"
    fi
    # just for make sure that the admin.password will be generated in time.
    fetch -s http://localhost:8081
    sleep 5
done

admin_pwd=$(cat /home/${USER}/sonatype-work/nexus3/admin.password)

##########################################################
# Save info on PLUGIN_INFO
echo "Nexus OSS Plugin. For more info please visit https://github.com/norfolkuncertainty/iocage-nexus-oss.git" >> /root/PLUGIN_INFO
echo "To access the Console use the default credentials: " >> /root/PLUGIN_INFO
echo "Nexus username: admin " >> /root/PLUGIN_INFO
echo "Nexus password: ${admin_pwd}" >> /root/PLUGIN_INFO

##########################################################
# Yei!!
IP=$(netstat -nr | grep lo0 | grep -v '::' | grep -v '127.0.0.1' | awk '{print $1}' | head -n 1)
echo "Post install completed! Console available at http://${IP}:8081 with credentials admin:${admin_pwd}"

