#!/bin/bash
#
# pluweb_install.sh
#
# Expects NO arguments
# Arg can be one of the following:
#
# Uncomment this statement for debug echos
DEBUG=1

scriptname="`basename $0`"
SCRIPTNAME="pluweb_install.sh"
UDR_INSTALL_LOGFILE="/var/log/udr_install.log"
SYSD_DIR="/etc/systemd/system"
USER=

function dbgecho { if [ ! -z "$DEBUG" ] ; then echo "$*"; fi }

# ===== function get_user

function get_user() {
   # Check if there is only a single user on this system
   if (( `ls /home | wc -l` == 1 )) ; then
      USER=$(ls /home)
   else
      echo "Enter user name ($(echo $USERLIST | tr '\n' ' ')), followed by [enter]:"
      read -e USER
   fi
}

# ==== function check_user
# verify user name is legit

function check_user() {
   userok=false
   dbgecho "$SCRIPTNAME: Verify user name: $USER"
   for username in $USERLIST ; do
      if [ "$USER" = "$username" ] ; then
         userok=true;
      fi
   done

   if [ "$userok" = "false" ] ; then
      echo "User name ($USER) does not exist,  must be one of: $USERLIST"
      exit 1
   fi

   dbgecho "using USER: $USER"
}

# ===== function start_service

function start_service() {
    service="$1"
    systemctl is-enabled "$service" > /dev/null 2>&1
    if [ $? -ne 0 ] ; then
        echo "ENABLING $service"
        systemctl enable "$service"
        if [ "$?" -ne 0 ] ; then
            echo "Problem ENABLING $service"
        fi
    fi
    # Is service alread running?
    systemctl is-active "$service"
    if [ "$?" -eq 0 ] ; then
        # service is already running, restart it to update config changes
        systemctl --no-pager restart "$service"
        if [ "$?" -ne 0 ] ; then
            echo "Problem re-starting $service"
        fi
    else
        # service is not yet running so start it up
        systemctl --no-pager start "$service"
        if [ "$?" -ne 0 ] ; then
            echo "Problem starting $service"
        fi
    fi
}

# ===== Main

echo -e "\n\tConfigure paclink-unix web server start-up\n"

# Be sure we're running as root
if [[ $EUID != 0 ]] ; then
   echo "Must be root."
   exit 1
fi

# Get list of users with home directories
USERLIST="$(ls /home)"
USERLIST="$(echo $USERLIST | tr '\n' ' ')"

# if there are any args on command line assume it's
# user name & callsign
if (( $# != 0 )) ; then
   USER="$1"
else
   get_user
fi

if [ -z "$USER" ] ; then
   echo "USER string is null, get_user"
   get_user
else
   echo "USER=$USER not null"
fi

check_user

# Setup node.js & modules required to run the plu web page.
echo
echo " == $SCRIPTNAME: Install nodejs, npm & node modules"

pushd /usr/local/src/paclink-unix/webapp

PROGLIST="nodejs npm"
apt-get install -y -q $PROGLIST
if [[ $? > 0 ]] ; then
    echo
    echo "$(tput setaf 1)Failed to install $PROGLIST, install from command line. $(tput sgr0)"
    echo
fi

npm install -g npm
npm install -g connect finalhandler serve-static
# Temporary
## Warning "root" does not have permission to access the dev dir #454
## https://github.com/nodejs/node-gyp/issues/454
sudo npm --unsafe-perm -g install websocket

echo
echo " == $SCRIPTNAME: Install jquery in directory $(pwd)"
# jquery should be installed in same directory as plu.html
npm install jquery

jquery_file="node_modules/jquery/dist/jquery.min.js"
if [ -f "$jquery_file" ] ; then
    cp "$jquery_file"  jquery.js
    echo "   Successfully installed: $jquery_file"
else
    echo
    echo "   $(tput setaf 1)ERROR: file: $jquery_file not found$(tput sgr0)"
    echo
fi

popd > /dev/null


# Set up systemd to run on boot
service="pluweb.service"
echo
echo " == $SCRIPTNAME: Setup systemd for $service"

LOCAL_SYSD_DIR="/home/$USER/n7nix/systemd/sysd"
cp -u $LOCAL_SYSD_DIR/$service $SYSD_DIR
# edit pluweb.service so starts as user

# Check if file exists.
if [ -f "$SYSD_DIR/$service" ] ; then
    dbgecho "Service already exists, comparing $service"
    diff -s $LOCAL_SYSD_DIR/$service $SYSD_DIR/$service
else
    echo "file $SYSD_DIR/$service DOES NOT EXIST"
    exit 1
fi

# Config the User & Group plu-server.js needs to run as
sed -i -e "/User=/ s/User=.*/User=$USER/" $SYSD_DIR/$service
sed -i -e "/Group=/ s/Group=.*/Group=$USER/" $SYSD_DIR/$service

# restart pluweb for new configuration to take affect
echo
echo " == $SCRIPTNAME: Start $service"

start_service $service
systemctl --no-pager status $service

echo
echo "$(date "+%Y %m %d %T %Z"): $SCRIPTNAME: script FINISHED" | tee -a $UDR_INSTALL_LOGFILE
echo
