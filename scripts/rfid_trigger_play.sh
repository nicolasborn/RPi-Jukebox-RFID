#!/bin/bash

# Reads the card ID from the command line (see Usage).
# Then attempts to play all files inside a folder with
# the given ID given.
#
# Usage:
# ./rfid_trigger_play.sh -c=1234567890
# or
# ./rfid_trigger_play.sh --cardid=1234567890

# VARIABLES TO CHANGE
# adjust these variables to match your system and configuration

ADDRESS="http://192.168.1.3:5005"

# If you use cards to change audio level, stop playing or shutdown the RPi,
# replace the following strings with the ID of the card. For example:
# Using the card ID 1234567890 to set the audio to mute, change this line:
# CMDMUTE="mute"
# to the following:
# CMDMUTE="1234567890"
# Leave everything untouched where you do not use a card.
CMDMUTE="%CMDMUTE%"
CMDVOL30="%CMDVOL30%"
CMDVOL50="%CMDVOL50%"
CMDVOL75="%CMDVOL75%"
CMDVOL80="%CMDVOL80%"
CMDVOL85="%CMDVOL85%"
CMDVOL90="%CMDVOL90%"
CMDVOL95="%CMDVOL95%"
CMDVOL100="%CMDVOL100%"
CMDSTOP="%CMDSTOP%"
CMDSHUTDOWN="%CMDSHUTDOWN%"
# The following commands control VLC playout
# next and prev play the preivous or next track in the playlist (== folder)
CMDNEXT="%CMDNEXT%"
CMDPREV="%CMDPREV%"
# pause VLC playout
CMDPAUSE="%CMDPAUSE%"
# resume VLC playout (makes only sense in combination with pause)
CMDPLAY="%CMDPLAY%"

# The absolute path to the folder whjch contains all the scripts.
# Unless you are working with symlinks, leave the following line untouched.
PATHDATA="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# NO CHANGES BENEATH THIS LINE

# Get args from command line (see Usage above)
for i in "$@"
do
case $i in
    -c=*|--cardid=*)
    CARDID="${i#*=}"
    ;;
esac
done

# If you want to see the CARDID printed, uncomment the following line
# echo CARDID = $CARDID

# Set the date and time of now
NOW=`date +%Y-%m-%d.%H:%M:%S`

# If the input is of 'special' use, don't treat it like a trigger to play audio.
# Special uses are for example volume changes, skipping, muting sound.

if [ "$CARDID" == "$CMDMUTE" ]
then
    amixer sset 'PCM' 0%
elif [ "$CARDID" == "$CMDVOL30" ]
then
    amixer sset 'PCM' 30%

elif [ "$CARDID" == "$CMDVOL50" ]
then
    amixer sset 'PCM' 50%

elif [ "$CARDID" == "$CMDVOL75" ]
then
    amixer sset 'PCM' 75%

elif [ "$CARDID" == "$CMDVOL85" ]
then
    amixer sset 'PCM' 85%

elif [ "$CARDID" == "$CMDVOL90" ]
then
    amixer sset 'PCM' 90%

elif [ "$CARDID" == "$CMDVOL95" ]
then
    amixer sset 'PCM' 95%

elif [ "$CARDID" == "$CMDVOL100" ]
then
    amixer sset 'PCM' 100%

elif [ "$CARDID" == "$CMDSTOP" ]
then
    # kill all running VLC media players
    sudo pkill vlc
elif [ "$CARDID" == "$CMDSHUTDOWN" ]
then
    # shutdown the RPi nicely
    sudo halt
elif [ "$CARDID" == "$CMDNEXT" ]
then
    # play next track in playlist (==folder)
    echo "next" | nc.openbsd -w 1 localhost 4212
elif [ "$CARDID" == "$CMDPREV" ]
then
    # play previous track in playlist (==folder)
    echo "prev" | nc.openbsd -w 1 localhost 4212
elif [ "$CARDID" == "$CMDPAUSE" ]
then
    # pause current track
    echo "pause" | nc.openbsd -w 1 localhost 4212
elif [ "$CARDID" == "$CMDNEXT" ]
then
    # play / resume current track
    echo "play" | nc.openbsd -w 1 localhost 4212
else
    # We checked if the card was a special command, seems it wasn't.
    # Now we expect it to be a trigger for one or more audio file(s).
    # Let's look at the ID, write a bit of log information and then try to play audio.

    # Expected folder structure:
    #
    # $PATHDATA + /../shared/audiofolders/ + $FOLDERNAME
    # Note: $FOLDERNAME is read from a file inside 'shortcuts'.
    #       See manual for details
    #
    # Example:
    #
    # $PATHDATA/../shared/audiofolders/list1/01track.mp3
    #                                       /what-a-great-track.mp3
    #
    # $PATHDATA/../shared/audiofolders/list987/always-will.mp3
    #                                         /be.mp3
    #                                         /playing.mp3
    #                                         /x-alphabetically.mp3
    #
    # $PATHDATA/../shared/audiofolders/webradio/filewithURL.txt

    # Add info into the log, making it easer to monitor cards
    echo "Card ID '$CARDID' was used at '$NOW'." > $PATHDATA/../shared/latestID.txt

	# Look for human readable shortcut in folder 'shortcuts'
	# check if CARDID has a text file by the same name - which would contain the human readable folder name
	if [ -f $PATHDATA/../shared/shortcuts/$CARDID ]
	then
	    # Read human readable shortcut from file
        FOLDERNAME=`cat $PATHDATA/../shared/shortcuts/$CARDID`
        # Add info into the log, making it easer to monitor cards
	    echo "This ID has been used before." >> $PATHDATA/../shared/latestID.txt
	else
        # Human readable shortcut does not exists, so create one with the content $CARDID
        # this file can later be edited manually over the samba network
        echo "$CARDID" > $PATHDATA/../shared/shortcuts/$CARDID
        FOLDERNAME=$CARDID
        # Add info into the log, making it easer to monitor cards
	    echo "This ID was used for the first time." >> $PATHDATA/../shared/latestID.txt
    fi
    # Add info into the log, making it easer to monitor cards
    echo "The shortcut points to audiofolder '$FOLDERNAME'." >> $PATHDATA/../shared/latestID.txt

    if [ -f $PATHDATA/../shared/audiofolders/$FOLDERNAME/sonos.txt ]
    then
        FILENAME="$PATHDATA/../shared/audiofolders/$FOLDERNAME/sonos.txt"
        while IFS='' read -r line || [[ -n "$line" ]]; do
            wget -O/dev/null -q "$ADDRESS/$line"
        done < "$FILENAME"        
    fi

    # if a folder $FOLDERNAME exists, play content
    if [ -d $PATHDATA/../shared/audiofolders/$FOLDERNAME ]
    then
        # create an empty string for the playlist
        PLAYLIST=""

        # loop through all the files found in the folder
        for FILE in $PATHDATA/../shared/audiofolders/$FOLDERNAME/*
        do
            # add file path to playlist followed by line break
            PLAYLIST=$PLAYLIST$FILE$'\n'
        done

        # write playlist to file using the same name as the folder with ending .m3u
        # wrap $PLAYLIST string in "" to keep line breaks
#        echo "$PLAYLIST" > $PATHDATA/../playlists/$FOLDERNAME.m3u

        # first kill any possible running vlc processn => stop playing audio
 #       sudo pkill vlc

        # now start the command line version of vlc loading the playlist
        # start as a background process (command &) - otherwise the input only works once the playlist finished
        #(cvlc $PATHDATA/../playlists/$FOLDERNAME.m3u &)
  #      (cvlc -I rc --rc-host localhost:4212 $PATHDATA/../playlists/$FOLDERNAME.m3u &)


    fi
fi
