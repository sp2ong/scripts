#!/bin/bash
#
# both_baud.sh
#
# Add configuration to allow both 1200 & 9600 baud when using an mDin6
# Y cable and both ports on a DRAWS hat.
#
# - Change ax25/port.conf
# - Add entries to ax25/ax25d.conf
# - Change call sign in ax25/axports
# - Change in direwolf.conf
#   - Verify there is a single ARATE entries one for each audio DEVICE
#   - ARATE sample-rate applies to the most recent ADEVICEn command
#   - ADEVICE = ADEVICE0
#   - Add 9600 baud modem speed

scriptname="`basename $0`"

AX25_CFGDIR="/usr/local/etc/ax25"
PORT_CFG_FILE="$AX25_CFGDIR/port.conf"
AX25D_CFG_FILE="$AX25_CFGDIR/ax25d.conf"

DIREWOLF_CFGFILE="/etc/direwolf.conf"

SED="sudo sed"

PRIMARY_DEVICE="udr0"
PRIMARY_SPEED="1200"
SECONDARY_DEVICE="udr1"
SECONDARY_SPEED="9600"

# ===== function get_callsign
function get_callsign() {
    filename="$AX25D_CFG_FILE"
    echo
    echo " == Call signs in $filename =="

    # Squish all spaces
#    grep -v "^#" $filename | tr -s '[[:space:]]' | cut -f2 -d' '
    CALLSIGN=$(grep -v "^#" /etc/ax25/ax25d.conf | tr -s '[[:space:]]' | grep "^\[" | cut -f1 -d' ' | sed 's/\[//g' | cut -d'-' -f1 | head -n1)
}

# ===== function get_device_name
function get_callsign() {
    filename="$AX25D_CFG_FILE"
    echo
    echo " == Call signs in $filename =="

    # Squish all spaces
#    grep -v "^#" $filename | tr -s '[[:space:]]' | cut -f2 -d' '
    CALLSIGN=$(grep -v "^#" /etc/ax25/ax25d.conf | tr -s '[[:space:]]' | grep "^\[" | cut -f1 -d' ' | sed 's/\[//g' | cut -d'-' -f1 | head -n1)
}


# ===== function set_port_conf file
# Set baud rate & receive_out disc/audio for both ports

# [port0]
# speed=9600
# receive_out=disc
#
# [port1]
# speed=1200
# receive_out=disc

function set_port_conf() {

    $SED -in "/\[port0\]/,/\[/ s/^speed=.*/speed=$PRIMARY_SPEED/" $PORT_CFG_FILE
    $SED -in '/\[port0\]/,/\[/ s/^receive_out=.*/receive_out=disc/' $PORT_CFG_FILE

    $SED -in "/\[port1\]/,/\[/ s/^speed=.*/speed=$SECONDARY_SPEED/" $PORT_CFG_FILE
    $SED -in '/\[port1\]/,/\[/ s/^receive_out=.*/receive_out=disc/' $PORT_CFG_FILE

    echo "DEBUG: File: $PORT_CFG_FILE set, verify"
    grep -i "^speed" $PORT_CFG_FILE
    grep -i "^receive_out" $PORT_CFG_FILE
}

# ===== function set_ax25d_conf
#
# Add the second port, ie. other side of sound device Assume first port
# (PRIMARY_DEVICE) has already been configured

function set_ax25d_conf() {
    get_callsign
    echo "DEBUG: using CALLSIGN: $CALLSIGN"

sudo tee -a $AX25D_CFG_FILE > /dev/null << EOT
#
[$CALLSIGN-10 VIA ${SECONDARY_DEVICE}]
NOCALL   * * * * * *  L
default  * * * * * *  - rmsgw /usr/local/bin/rmsgw rmsgw -P %d %U
#
[$CALLSIGN VIA ${SECONDARY_DEVICE}]
NOCALL   * * * * * *  L
default  * * * * * *  - $USER /usr/local/bin/wl2kax25d wl2kax25d -c %U -a %d
EOT

    left_entry_cnt=$(grep  "$CALLSIGN" $AX25D_CFG_FILE | grep -c "udr0")
    right_entry_cnt=$(grep  "$CALLSIGN" $AX25D_CFG_FILE | grep -c "udr1")
    echo "DEBUG: call sign count: Left: $left_entry_cnt, Right: $right_entry_cnt"
}

# ===== function direwolf_set_baud_first

# Set baud rate on MODEM line for the FIRST modem channel

direwolf_set_baud_first() {

    modem_speed="$1"

    echo "$scriptname: set $DIREWOLF_CFGFILE first baud rate to: $modem_speed" | $TEE_CMD

    # Modify first occurrence of MODEM configuration line
    sudo sed -i "0,/^MODEM/ s/^MODEM .*/MODEM $modem_speed/" $DIREWOLF_CFGFILE

    # Modify both occurrences of MODEM configuration line
    # sudo sed -i "/^MODEM/ s/^MODEM .*/MODEM $modem_speed/" $DIREWOLF_CFGFILE

    modem_cnt=$(grep "^MODEM" $DIREWOLF_CFGFILE | wc -l)
    if (( modem_cnt != 2 )) ; then
        echo "WARNING: Wrong number of modem entries: $modem_cnt"
    fi
}


# ===== function direwolf_set_baud_second

# Set baud rate on MODEM line for the SECOND modem channel

direwolf_set_baud_second() {

    modem_speed="$1"

    echo "$scriptname: set $DIREWOLF_CFGFILE second baud rate to: $modem_speed" | $TEE_CMD

    # Modify second occurrence of MODEM configuration line
    sudo sed -i -e "0,/^MODEM /! {/^MODEM/ s/^MODEM .*/MODEM $modem_speed/}" $DIREWOLF_CFGFILE

    # Modify both occurrences of MODEM configuration line
    # sudo sed -i "/^MODEM/ s/^MODEM .*/MODEM $modem_speed/" $DIREWOLF_CFGFILE

    modem_cnt=$(grep "^MODEM" $DIREWOLF_CFGFILE | wc -l)
    if (( modem_cnt != 2 )) ; then
        echo "WARNING: Wrong number of modem entries: $modem_cnt"
    fi
}


# ===== function display_baud_cfg_files

function display_baud_cfg_files() {

#    for file in "$AX25D_CFG_FILE" "$PORT_CFG_FILE"  ; do
        file="$AX25D_CFG_FILE"
        echo
        echo " === Dumping file: $file"
        # Display all lines without a comment character
        grep ^[^#] $file

        file="$PORT_CFG_FILE"
        echo
        echo " === Dumping file: $file"
        # Display all lines without a comment character
        grep ^[^#] $file | head -n 9
#    done

    echo
    echo " === Check direwolf config for modem speed"
#    grep "^MODEM" $DIREWOLF_CFGFILE

    modem_cnt=$(grep "^MODEM" $DIREWOLF_CFGFILE | wc -l)
    if (( modem_cnt == 2 )) ; then
        port_speed1=$(grep "^MODEM" /etc/direwolf.conf | head -n1 | cut -f2 -d' ')
        port_speed2=$(grep "^MODEM" /etc/direwolf.conf | tail -n1 | cut -f2 -d' ')
        echo "First port speed: $port_speed1, Second port speed: $port_speed2"
	if (( port_speed1 == port_speed2 )) ; then
	    echo "WARNING: direwolf not configured for 2 differnet baud rates."
	else
	    echo "Direwolf config OK for modem speed settings."
	fi

    else
        echo "WARNING: Wrong number of modem entries: $modem_cnt"
    fi

    echo
    echo " === Check direwolf config ARATE value(s)"

    echo "DEBUG: check arate, count: $(grep -i "^arate " $DIREWOLF_CFGFILE | wc -l)"
    grep -i "^arate " $DIREWOLF_CFGFILE

    # Do the ptt gpio's need to be different?
    echo
    echo " === Check direwolf config for PTT gpio"
    grep -i "^ptt gpio" $DIREWOLF_CFGFILE

}

# ==== function display arguments used by this script

usage () {
	(
	echo "Usage: $scriptname [-s][-d][-h][status]"
        echo "  status          display contents of both baud rates configuration"
        echo "  -h              Display this message."
        echo
	) 1>&2
	exit 1
}

# ===== main

while [[ $# -gt 0 ]] ; do
APP_ARG="$1"

    case $APP_ARG in
        -s|status)
            echo
            echo "===== Check configuration for dual baud rates"
	    display_baud_cfg_files
	    exit 0
        ;;
        -d|--debug)
            DEBUG=1
            echo "Debug mode on"
       ;;
        -h|--help|-?)
            usage
            exit 0
       ;;
       *)
            echo "Unrecognized command line argument: $APP_ARG"
            usage
            exit 0
       ;;

    esac

shift # past argument
done

# ===== Change file: /etc/ax25/port.conf
#
echo " ==== set port config file"
set_port_conf

# ===== Change file: /etc/ax25/ax25d.conf
echo " ==== set ax.25 daemon config file"
sec_device_cnt=$(grep -i "udr1" $AX25D_CFG_FILE | wc -l)
if (( sec_device_cnt < 2 )) ; then
    echo "Editing file: $AX25D_CFG_FILE"
    set_ax25d_conf
else
    echo "AX25D file: $AX25D_CFG_FILE ALREADY set"
fi

# ===== /etc/direwolf.conf changes
echo " ==== set direwolf config file"

# Should be only 1 arate entery per audio device.
arate_cnt=$(grep -i "^arate " $DIREWOLF_CFGFILE | wc -l)
if [ -z $arate_cnt ] ; then
    arate_cnt=0
fi
echo "Debug: first arate cnt: $arate_cnt"
if (( arate_cnt == 0 )) ; then
    echo "Setting arate in $DIREWOLF_CFGFILE"
    $SED -in '/^ADEVICE /a ARATE 48000' $DIREWOLF_CFGFILE
else
    arate_val=$(grep -i "^arate" /etc/direwolf.conf | cut -f2 -d' ')
    echo "DEBUG: arate already set to: $arate_val"
fi

echo "Confirm 9600 baud is set"
port_speed1=$(grep "^MODEM" /etc/direwolf.conf | head -n1 | cut -f2 -d' ')
port_speed2=$(grep "^MODEM" /etc/direwolf.conf | tail -n1 | cut -f2 -d' ')

if (( port_speed1 == port_speed2 )) ; then
    echo "WARNING: direwolf not configured for 2 differnet baud rates ... will edit."
fi

# Setup direwolf modem baud rates

    direwolf_set_baud_first "$PRIMARY_SPEED"
    direwolf_set_baud_second "$SECONDARY_SPEED"

# Count number of MODEM speeds set
modem_cnt=$(grep -c "^MODEM" /etc/direwolf.conf)

port_speed1=$(grep "^MODEM" /etc/direwolf.conf | head -n1 | cut -f2 -d' ')
port_speed2=$(grep "^MODEM" /etc/direwolf.conf | tail -n1 | cut -f2 -d' ')
echo "After edit: modem settings: $modem_cnt,  First port speed: $port_speed1, Second port speed: $port_speed2"
