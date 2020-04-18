#!/bin/bash -l
#===============================================================================
#  FILE: castmyalarm.sh
#  USAGE: ./stream2chromecast/castmyalarm.sh
#	 USAGE: crontab e.g. 20  9   *   *   1-5 /bin/bash /opt/stream2chromecast/castmyalarm.sh
#
#  DESCRIPTION: takes a random radio station stream from your defined array
#               and streams it to your defined google chromecast audio devices
#
#  REQUIREMENTS: - Google Chromecast Audio as renderer, - PC/SOC as streaming device
#                - https://github.com/dancardy/stream2chromecast.git to provide a CCA-stream
#          BUGS: Some Stations won't work. s2c is not intended to cast webstreams
#         NOTES: The stations defined are working fine, however
#         NOTES: Align the rooms to your needs
#        AUTHOR: Andre Stemmann
#       CREATED: 18.04.2020
#      REVISION: v0.1
#===============================================================================

# ===============================================================================
# TODO LIST
# ===============================================================================
# stream to mobile if chromecast fail
# add paramter e.g. specific rooms to choose from

# ===============================================================================
# BASE VARIABLES
# ===============================================================================
snek=$(which python)
s2c="/opt/wecker/stream2chromecast/stream2chromecast.py"
user=$(echo $HOME|rev|cut -d"/" -f1|rev)
room1=""  # Google Chromecast Audio Name here e.g. bedroom
r1t="5m"  # Given streamtime for bedroom
room2=""  # Google Chromecast Audio Name here e.g. bathroom
r2t="30m" # Given streamtime for bathroom

# simple array. add/remove as you prefer
radiostations=(http://stream.antenne.com/antenne-nds/mp3-128/listenlive/play.m3u
http://stream.antenne.com/antenne-nds-80er/mp3-128/listenlive/play.m3u
http://stream.antenne.com/antenne-nds-90er/mp3-128/listenlive/play.m3u
http://stream.antenne.com/rock/mp3-128/listenlive/play.m3u
http://stream.antenne.com/oldies/mp3-128/listenlive/play.m3u
http://stream.antenne.com/charts/mp3-128/listenlive/play.m3u
http://live96.106acht.de/listen.pls
http://stream.laut.fm/blitzfm
http://live96.106acht.de
http://streams.deltaradio.de/delta-live/mp3-192/mediaplayerdeltaradio
http://player.ffn.de/ffn.mp3
http://streams.radiobob.de/bob-live/mp3-192/mediaplayer
http://mp3.webradio.rockantenne.de:80
http://mp3channels.webradio.rockantenne.de/alternative
http://mp3channels.webradio.rockantenne.de/classic-perlen)

# ===============================================================================
# BASE FUNCTIONS
# ===============================================================================
# Scan my CCA devices available
devicecheck () {
    set -o nounset
    set -e
    devices=("$(python ${s2c} -devicelist|grep -Eo "${room1}|${room2}")")
    sleep 5s
    for i in "${devices[@]}";
    do
        if [[ $i == *"${room1}"* ]]; then
            python ${s2c} -devicename ${room1} -status
            if [ $? -ne "0" ]; then STATUS_ROOM1="1"; else STATUS_ROOM1="0"; fi
        else
            STATUS_ROOM1="1"
        fi
        sleep 5s
        if [[ $i == *"${room2}"* ]]; then
            python ${s2c} -devicename ${room2} -status
            if [ $? -ne "0" ]; then STATUS_ROOM2="1" ; else STATUS_ROOM2="0";  fi
        else
            STATUS_ROOM2="1"
        fi
        sleep 5s
    done
}

stationpoker () {
    RANDOM=$$$(date +%s)
    randomstation=$(printf "%s\\n" "${radiostations[@]}"|shuf|head -1)
    logger "Selecting a random radiostream"
    while [[ -z $randomstation ]]
    do
        logger "Picked station index is empty, try to pick another"
    done < <(randomstation=${radiostations[$RANDOM % ${#radiostations[@]} ]})
}

streamcheck () {
    logger "Re-Check if stream $randomstation is online"
    response=$(curl --write-out %'{http_code}' --silent -I --insecure --output /dev/null "$randomstation")
    while [[ $response != @(20*|30*) ]]
    do
        logger "Stream $randomstation is offline, HTTP-status-code was: $response. Picking another stream"
        stationpoker
        response=$(curl --write-out %'{http_code}' --silent -I --insecure --output /dev/null "$randomstation")
        logger "New stream Is $randomstation. HTTP-status-code is: $response"
    done
    logger "Stream $randomstation is online"
}

cast2room1 () {
    # reset/level audio output
    $snek ${s2c} -devicename ${room1} -setvol 0.0
    $snek ${s2c} -devicename ${room1} -setvol 0.01
    sleep 5s
    logger "Creating screen session for ${room1}"
    screen -dmS ${room1}
    logger "${room1} is online, start casting $randomstation"
    screen -S ${room1} -p 0 -X stuff ". /home/${user}/.profile; $snek ${s2c} -port 4100 -devicename ${room1} -playurl ${randomstation}\\n"
    sleep $r1t
    $snek ${s2c} -devicename ${room1} -setvol 0.02
    sleep 20s
    $snek ${s2c} -devicename ${room1} -setvol 0.03
    sleep 20s
    $snek ${s2c} -devicename ${room1} -setvol 0.04
    sleep 20s
    $snek ${s2c} -devicename ${room1} -setvol 0.05
    sleep 20s
    $snek ${s2c} -devicename ${room1} -setvol 0.06
    # kill room1 after 6mins
    sleep $r1t
    logger "Times over, killing ${room1} stream"
    $snek ${s2c} -devicename ${room1} -stop
    screen -X -S ${room1} quit
    logger "killed screensession ${room1}"
}

cast2room2 () {
    # reset/level audio output
    $snek ${s2c} -devicename ${room2} -setvol 0.0
    $snek ${s2c} -devicename ${room2} -setvol 0.2
    sleep 5s
    logger "Creating screen session for ${room2}"
    screen -dmS ${room2}
    logger "${room2} is online, start casting $randomstation"
    screen -S ${room2} -p 0 -X stuff ". /home/${user}/.profile; $snek ${s2c} -port 4100 -devicename ${room2} -playurl ${randomstation}\\n"
    sleep $r2t
    logger "Times over, killing ${room2} stream"
    $snek ${s2c} -devicename ${room2} -stop
    screen -X -S ${room2} quit
    logger "killed screensession ${room2}"
    exit 0
}

# ===============================================================================
# MAIN
# ===============================================================================
# seek CCAs
devicecheck
if [[ $STATUS_ROOM1 -eq "0" ]] || [[ $STATUS_ROOM2 -eq "0" ]]; then
    logger "Whether ${room2} or ${room1} is online"
    stationpoker
    streamcheck
    if [ $STATUS_ROOM1 -eq "0" ]; then
        cast2room1
    else
        logger "CCA in ${room1} is offline"
    fi

    if [ $STATUS_ROOM2 -eq "0" ]; then
        cast2room2
    else
        logger "CCA in ${room2} is offline"
        exit 0
    fi
else
    logger "Whether ${room2} nor ${room1} is online. Exiting"
    exit 0
    fi
    exit 0
