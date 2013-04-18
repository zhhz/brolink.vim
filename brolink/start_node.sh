#! /bin/bash

#
# !!! IMPORTANT !!!!
#    MAKE SURE THESE ARE CORRECT FOR YOUR SYSTEM
PGREP=/usr/bin/pgrep
AWK=/usr/bin/awk
NODE=/usr/local/bin/node
PS=/bin/ps
PS_FLAGS=wux
AWK_PROG='{print $6}'  # on OS X and ubuntu res mem size is $6 in "ps wux"
PAUSE_TIME=4

MAX_MEM=100 # max memory in MB
N_CRASHES=2 # number of crashes allowed per N_MIN
N_MIN=1

txtund=$(tput sgr 0 1)          # Underline
txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) #  red
bldylw=${txtbld}$(tput setaf 3) #  yellow
bldgrn=${txtbld}$(tput setaf 2) #  green
txtrst=$(tput sgr0)             # Reset
INFO=${bldgrn}INFO:${txtrst}
ERROR=${bldred}ERROR:${txtrst}
WARN=${bldylw}WARNING:${txtrst}

SERVER_JS="~/vim/bundle/brolink.vim/brolink/brolink.js"

function check_progs
{
    if [ ! -f $NODE ]; then echo "$ERROR Missing $NODE, aborting"; exit 1; fi
    if [ ! -f $PGREP ]; then echo "$ERROR Missing $PGREP, aborting"; exit 1; fi
    if [ ! -f $AWK ]; then echo "$ERROR Missing $AWK, aborting"; exit 1; fi
    if [ ! -f $PS ]; then echo "$ERROR Missing $PS, aborting"; exit 1; fi
}

function already_running
{
    echo "'node brolink.js' already be running. Cowardly refusing to start another."
    exit 1
}

check_progs

# bash only does integer arithmetic, so we'll mult by 100
# to avoid decimals
RESTART_WEIGHT=0
MAX_WEIGHT=$(( $N_MIN * 6000 ))
WEIGHT_TIME_CHUNK=$(( (6000 * $N_MIN) / $N_CRASHES ))
FADE_TIME_CHUNK=$(( ($MAX_WEIGHT / $N_CRASHES) / (600 / ($PAUSE_TIME * 10)) ))
#echo $WEIGHT_TIME_CHUNK $MAX_WEIGHT $FADE_TIME_CHUNK

# first make sure it's not running.
PID=`$PGREP -n -f "$NODE $SERVER_JS"`
if [ "$PID" != "" ]; then
    already_running $SEVER_JS
fi

# now launch it and start monitoring
echo "$INFO Launching brolink node server ..."
$NODE $SERVER_JS &

while true
do
    sleep $PAUSE_TIME

    PID=`$PGREP -n -f "$NODE $SERVER_JS"`
    NEED_RESTART=no
    if [ "$PID" == "" ]; then
        echo
        echo "$WARN Node appears to have crashed."
        NEED_RESTART=yes
    else
        # check memory usage
        MEM_USAGE=`$PS $PS_FLAGS $PID | $AWK 'NR>1' | $AWK "$AWK_PROG"`
        MEM_USAGE=$(( $MEM_USAGE / 1024 ))
        if [ $MEM_USAGE -gt $MAX_MEM ];
        then
            echo "$ERROR node has exceed permitted memory of $MAX_MEM mb, restarting."
            kill $PID
            NEED_RESTART=yes
        fi
    fi
    RESTART_WEIGHT=$(($RESTART_WEIGHT - $FADE_TIME_CHUNK))
    if [ "$RESTART_WEIGHT" -lt "0" ];
    then
        RESTART_WEIGHT=0
    fi
    if [ "$NEED_RESTART" == "yes" ];
    then
        if [ "$RESTART_WEIGHT" -le "$MAX_WEIGHT" ];
        then
            echo "$INFO Restarting..."
            $NODE $SERVER_JS&
            RESTART_WEIGHT=$(( $RESTART_WEIGHT + $WEIGHT_TIME_CHUNK ))
        else
            echo "$ERROR Too many restarts. Aborting."
            exit -1
        fi
    fi
done
