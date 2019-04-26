#!/bin/bash

# Command line arguments parsing
while [ "$1" != "" ]; do
  case $1 in 
    -f | --file)
      shift;
      filepath=$1;
      ;;

    -o | --outpath)
      shift;
      out_dir=$1;
      ;;

    -c | --chunksize)
      shift;
      chunksize=$1;
      ;;
  esac

  shift
done

set -e
trap '"Some command filed with exit code $?."' EXIT

# The minimum file size to allow splitting
SIZE_THRESHOLD=20;

# EXIT CODES:
SUCCESS=0;
FAILURE=1;
NO_SPLIT_NEEDED=2;

# Check that ffmpeg/ffprobe is installed and is executable
if ! [ -x "$(command -v ffmpeg)" ] || ! [ -x "$(command -v ffprobe)" ]; then
  echo "ffmpeg/ffprobe not installed/executable! Exiting...";
  exit $FAILURE;
fi

if [ -z $filepath ]; then
  echo "No file specified.";
  exit $FAILURE;
fi

file_size=$(ffprobe -i $filepath -show_entries format=size -v quiet -of csv="p=0");
file_size=$(echo "scale=2; $file_size / 1000000" | bc -l);
file_format="${filepath#*.}";

if [ $(echo "$file_size <= $SIZE_THRESHOLD" | bc -l) -eq 1 ]; then
  echo "File size is: $file_size. No need to split";
  exit $NO_SPLIT_NEEDED;
fi

# The process used to split here is slow (Full re-encoding) to prevent frame loss
# See: http://www.markbuckler.com/post/cutting-ffmpeg/
ffmpeg_split() {
  ffmpeg -i $filepath -ss $prev -strict -2 -t $step  "out_$part.$file_format"  -hide_banner -loglevel panic;
}

# Get the duration of the file
duration=$(ffprobe -i $filepath -show_entries format=duration -v quiet -of csv="p=0");

if [ -z $chunksize ]; then
  chunksize=10;
fi

step=$chunksize;
part=0;
prev=0;

# Save the original directory and go to output directory
current_dir=$pwd;
cd $out_dir;

if [ $(echo "$step >= $duration" | bc -l) ]; then
  step=$duration
  ffmpeg_split
  exit $SUCCESS;
fi

while [ $(echo "$prev < $duration" | bc -l) != 0 ]; do
  part=$((part + 1));
  if [ $(echo "$prev + $step > $duration" | bc -l) -eq 1 ]; then
    exit $SUCCESS;
  fi

  prev=$(echo "$prev + $step" | bc -l);
  ffmpeg_split;
done

# Return to the original directory
cd $current_dir;

exit $SUCCESS;