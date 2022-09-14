#!/bin/bash

# Usage:
#    avi_compress_movie.sh /path/to/input_movie.avi /path/to/output_movie.mp4

# Convert the AVI to MP4 and if successful then delete the AVI.

source ~/.bashrc

avi_path="$1"
mp4_path="$2"

# Convert the AVI to MP4.
/misc/local/ffmpeg-0.10/bin/ffmpeg -nostats -y -i "$avi_path" -threads 2 -s 540x460 -crf 20 "$mp4_path"

# Check if the movie was converted correctly.
ffmpeg_result=$?
if [ ! $ffmpeg_result -eq 0 ]
then
	echo "ffmpeg failed with error code $ffmpeg_result" >&2
	rm -f "$mp4_path"
	exit $ffmpeg_result
fi

# Check if the movie file is non-empty.
if [ ! -s "$mp4_path" ]
then
	echo "MP4 is missing or empty at $mp4_path" >&2
	exit 1
fi

# Make sure the frame counts are the same.
avi_frame_count=$(/misc/local/ffmpeg-0.10/bin/ffprobe -show_streams -loglevel quiet "$avi_path" | grep 'nb_frames=' | cut -f 2 -d '=')
mp4_frame_count=$(/misc/local/ffmpeg-0.10/bin/ffprobe -show_streams -loglevel quiet "$mp4_path" | grep 'nb_frames=' | cut -f 2 -d '=')
if [ $avi_frame_count -eq $mp4_frame_count ]
then
	echo "MP4 has correct number of frames"
	rm -f "$avi_path"
else
	echo "MP4 has incorrect number of frames: $frame_count" >&2
	exit 1
fi
