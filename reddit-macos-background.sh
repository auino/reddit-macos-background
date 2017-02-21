#!/bin/bash

# 
# reddit-macos-background
# Author: Enrico Cambiaso
# Email: enrico.cambiaso[at]gmail.com
# GitHub project URL: https://github.com/auino/reddit-macos-background
# 

# --- --- --- --- ---
# CONFIGURATION BEGIN
# --- --- --- --- ---

# subreddit name
SUBREDDIT="EarthPorn"

# set to 0 if you want to use (also) portrait photos as background
ONLY_LANDSCAPE_MODE=1

# temporary script directory (without final '/' slash)
TMPDIR="/tmp"

# desired resolution
RESOLUTION="1920x1080"

# images of a specific user
FEED="http://www.reddit.com/r/${SUBREDDIT}/search.rss?q=${RESOLUTION}&restrict_sr=on"

# adopted user agent
USERAGENT="Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8J2 Safari/6533.18.5"

# download all images to a specific folder $DOWNLOAD_DIR, or set a single image as background each time?
BATCH_DOWNLOAD=1

# where should images be stored (without final '/' slash)?
DOWNLOAD_DIR="$HOME/Pictures/reddit"

# MD5 function command
MD5COMMAND=md5

# --- --- --- --- ---
#  CONFIGURATION END
# --- --- --- --- ---

# getting feed from Reddit
curl -s -L -A "$USERAGENT" "$FEED"|tr '<' '\n'|tr '>' '\n'|sed -e 's/&lt;/</g'|sed -e 's/&gt;/>/g'|sed -e 's/&quot;/"/g'|tr ' ' '\n'|grep href|grep "jpg"|awk -F'"' '{print $2}' > $DIR/reddit_list.txt

# checking if batch download is configured or not
if [ $BATCH_DOWNLOAD -gt 0 ]; then
	# creating download directory, if needed
	mkdir "$DOWNLOAD_DIR" 2> /dev/null
	# cycling over all found images
	for IMG in $(cat $TMPDIR/reddit_list.txt); do
		# printing basic information
		echo "Getting image"
		# getting image data from url
		echo $IMG
		curl -s "$IMG" -o $TMPDIR/reddit_img.png
		# getting image dimensions
		IMG_W=`sips -g pixelWidth $TMPDIR/reddit_img.png|tail -n 1|awk '{print $2}'`
		IMG_H=`sips -g pixelHeight $TMPDIR/reddit_img.png|tail -n 1|awk '{print $2}'`
		echo "Image size is ${IMG_W} x ${IMG_H}"
		# checking if image is "good"
		if [ ! $ONLY_LANDSCAPE_MODE ] || [ $IMG_W -gt $IMG_H ]; then continue ; fi
		# checking if images is already saved
		MD5=`$MD5COMMAND $TMPDIR/reddit_img.png|awk '{print $4}'`
		FOUND=`$MD5COMMAND $DOWNLOAD_DIR/*|grep $MD5|wc -l|awk '{print $1}'`
		if [ $FOUND -le 0 ]; then
			mv $TMPDIR/reddit_img.png $DOWNLOAD_DIR/$MD5.png
		fi
	done
	exit 0
fi

# getting elements count
COUNT=`cat $DIR/reddit_list.txt|wc -l|awk '{print $1}'`

# cycling until a "good" image if found
FOUND=0
for i in $(seq 1 $COUNT); do
	# printing basic information
	echo "Getting image"

	# getting a random element index
	RND=`expr $RANDOM % $COUNT`

	# getting the image url from index
	IMG=`cat $TMPDIR/reddit_list.txt|tail -n +$RND|head -n 1`

	# getting image data from url
	echo $IMG
	curl -s "$IMG" -o $TMPDIR/reddit_img.png

	# getting image dimensions
	IMG_W=`sips -g pixelWidth $TMPDIR/reddit_img.png|tail -n 1|awk '{print $2}'`
	IMG_H=`sips -g pixelHeight $TMPDIR/reddit_img.png|tail -n 1|awk '{print $2}'`
	echo "Image size is ${IMG_W} x ${IMG_H}"

	# checking if image is "good"
	if [ ! $ONLY_LANDSCAPE_MODE ] || [ $IMG_W -gt $IMG_H ]; then
		FOUND=1
		break
	fi
done

if [ $FOUND ]; then
	# setting image as background
	echo "Setting downloaded image as background"

	osascript -e 'tell application "System Events"
		set desktopCount to count of desktops
		repeat with desktopNumber from 1 to desktopCount
			tell desktop desktopNumber
				set picture to "'$TMPDIR'/reddit_img.png"
			end tell
		end repeat
	end tell'

	killall Dock
else
	echo "No image found"
fi
