#!/bin/bash

# The minimum file size to allow splitting
SIZE_THRESHOLD=1;

# EXIT CODES:
SUCCESS=0;
FAILURE=1;
NO_SPLIT_NEEDED=2;

print_help() {
  echo "====================== Script Options ======================";
  echo "-f | --file      : the file to split";
  echo "-o | --outpath   : the directory to put the split files in";
  echo "-c | --chunklen : the max length of each split file";
  echo "-p | --prefix    : the prefix in the file name of the parts"
  echo "============================================================";

  exit 0;
}

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

    -c | --chunklen)
      shift;
      chunklen=$1;
      ;;

    -h | --help)
      print_help;
      ;;

    -p | --prefix)
      shift;
      output_file_prefix=$1;
      ;;
  esac

  shift
done

set -e;
trap 'exit_on_error' EXIT;

exit_on_error() {
  exit_code=$?;

  if [ $exit_code -eq $FAILURE ]; then
    echo "Process failed due to some error!";
  else
    echo "Process finished successfully!";
  fi
}


# Check that ffmpeg/ffprobe is installed and is executable
if ! [ -x "$(command -v ffmpeg)" ] || ! [ -x "$(command -v ffprobe)" ]; then
  echo "ffmpeg/ffprobe not installed/executable! Exiting...";
  exit $FAILURE;
fi

if [ -z $filepath ]; then
  echo "No file specified.";
  exit $FAILURE;
fi

if [ -z $output_file_prefix ]; then
  output_file_prefix="out";
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
  ffmpeg -i $filepath -ss $prev -strict -2 -t \
  $chunklen  "$output_file_prefix-$part.$file_format" \
  -hide_banner -loglevel panic;
}

# Get the duration of the file
duration=$(ffprobe -i $filepath -show_entries format=duration -v quiet -of csv="p=0");

# Default chunk length is 5 minutes
if [ -z $chunklen ]; then
  chunklen=300;
fi

# Save the original directory and go to output directory
current_dir=$pwd;
cd $out_dir;

part=0;
prev=0;

# if the chink length is greater than the duration of the video
# then only re-encoding is needed. No splitting the file.
if [ $(echo "$chunklen >= $duration" | bc -l) -eq 1 ]; then
  chunklen=$duration
  ffmpeg_split
  exit $SUCCESS;
fi

while [ $(echo "$prev < $duration" | bc -l) != 0 ]; do
  part=$((part + 1));
  ffmpeg_split;
  prev=$(echo "$prev + $chunklen" | bc -l);
done

# Return to the original directory
cd $current_dir;
exit $SUCCESS;