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
DESKTOP_WIDTH=`system_profiler SPDisplaysDataType |grep Resolution|awk '{print $2}'`
DESKTOP_HEIGHT=`system_profiler SPDisplaysDataType |grep Resolution|awk '{print $4}'`
DESKTOP_RESOLUTION="${DESKTOP_WIDTH}x${DESKTOP_HEIGHT}"

# keep current dekstop resolution aspect ratio (1) or not (0)?
KEEP_ASPECT_RATIO=0

# only search for same resolution images (1) or not (0)?
ONLY_SAME_RESOLUTION=0

# ignore low resolution images (1) or not (0)?
IGNORE_LOWRES_IMAGES=1

# restrict results ('on') or not ('off')
RESTRICT=off

# operating system identification
MACOS=0
if [ "$(uname)" == "Darwin" ]; then MACOS=1 ; fi

# images of a specific user
Q='x' # generic string including several different resolutions
if [ $ONLY_SAME_RESOLUTION ]; then Q=$DESKTOP_RESOLUTION ; fi
FEED="http://www.reddit.com/r/${SUBREDDIT}/search.rss?q=$Q&restrict_sr=${RESTRICT}&sort=new"

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
curl -s -L -A "$USERAGENT" "$FEED" > $TMPDIR/reddit_data.rss
cat $TMPDIR/reddit_data.rss|tr '<' '\n'|tr '>' '\n'|sed -e 's/&lt;/</g'|sed -e 's/&gt;/>/g'|sed -e 's/&quot;/"/g'|tr ' ' '\n'|grep href|grep "jpg"|awk -F'"' '{print $2}' > $TMPDIR/reddit_list.txt

# checking if batch download is configured or not
if [ $BATCH_DOWNLOAD -gt 0 ]; then
	# creating download directory, if needed
	mkdir "$DOWNLOAD_DIR" 2> /dev/null
	# calculating desired aspect ratio
	F=1000
	DESKTOP_ASPECT_RATIO=`expr $DESKTOP_WIDTH \* $F / $DESKTOP_HEIGHT`
	echo "Desktop resolution is $DESKTOP_WIDTH x $DESKTOP_HEIGHT"
	# cycling over all found images
	for IMG in $(cat $TMPDIR/reddit_list.txt); do
		# printing basic information
		echo "Getting image: $IMG"
		# getting image data from url
		curl -s "$IMG" -o $TMPDIR/reddit_img.png
		# getting image dimensions
		IMG_W=`sips -g pixelWidth $TMPDIR/reddit_img.png|tail -n 1|awk '{print $2}'`
		IMG_H=`sips -g pixelHeight $TMPDIR/reddit_img.png|tail -n 1|awk '{print $2}'`
		#echo "Image size is ${IMG_W} x ${IMG_H}"
		# checking resolution
		if [ $ONLY_SAME_RESOLUTION -gt 0 ]; then
			if [ $IMG_W -ne $DESKTOP_WIDTH ] || [ $IMG_H -ne $DESKTOP_HEIGHT ]; then continue; fi
		fi
		# checking image quality
		if [ $IGNORE_LOWRES_IMAGES -gt 0 ]; then
			if [ $IMG_W -lt $DESKTOP_WIDTH ] || [ $IMG_H -lt $DESKTOP_HEIGHT ]; then continue; fi
		fi
		# checking aspect ratio, if needed
		IMG_ASPECT_RATIO=`expr $IMG_W \* $F / $IMG_H`
		if [ $KEEP_ASPECT_RATIO -gt 0 ] && [ $DESKTOP_ASPECT_RATIO -ne $IMG_ASPECT_RATIO ]; then continue ; fi
		# checking if image shot mode is "good"
		if [ $ONLY_LANDSCAPE_MODE -gt 0 ] && [ $IMG_W -le $IMG_H ]; then continue ; fi
		# checking if images is already saved
		MD5=`$MD5COMMAND $TMPDIR/reddit_img.png|awk '{print $4}'`
		FOUND=`cat $DOWNLOAD_DIR/.allimages.txt|grep $MD5|wc -l|awk '{print $1}'`
		if [ $FOUND -gt 0 ]; then continue ; fi
		echo "Saving..."
		mv "$TMPDIR/reddit_img.png" "$DOWNLOAD_DIR/$MD5.png"
		echo "$MD5" >> "$DOWNLOAD_DIR/.allimages.txt"
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

	if [ $MACOS -gt 0 ]; then
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
		# works on Gnome
		gsettings set org.gnome.desktop.background picture-uri "file://$TMPDIR/reddit_img.png"
	fi
else
	echo "No image found"
fi
