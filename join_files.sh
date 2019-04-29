#!/bin/bash
set -e;

print_help() {
  echo "======================= Script Help ========================";
  echo "  THIS SCRIPT ASSUMES ALL THE FILENAMES INCLUDE EXTENSIONS"
  echo " ";
  echo "-f | --files     : Space delimited (IN ORDER) list of files";
  echo "-o | --outpath   : the directory to put the split files in";
  echo "-n | --name      : the name of the joined file";
  echo "-c | --cleanup   : remove the parts after joining?";
  echo "============================================================";

  exit 0;
}

SUCCESS=0;
FAILURE=1;

files=();
while [ "$1" != "" ]; do
  case $1 in 
    -o | --outpath)
      shift;
      out_dir=$1;
      ;;
    
    -f | --files)
      ;;

    -n | --name)
      shift;
      output_name=$1;
      ;;
    
    -c | --cleanup)
      cleanup=1;
      ;;

    -h | --help)
      print_help;
      exit 0;
      ;;

    *)
      files+=("$1");
      ;;
  esac

  shift;
done

if [ -f ./temp.txt ]; then
  rm -f ./temp.txt;
fi

touch temp.txt;

for file in "${files[@]}" 
do
  echo "file '$file'" >> temp.txt;
done

file_cleanup() {
  for file in "${files[@]}"
  do
    rm -f "$file";
  done
}

arr_len="${#files[@]}";

if [ $arr_len -eq 1 ]; then
  mv "${files[0]}" $out_dir/$output_name;
  file_cleanup;
  exit $SUCCESS;
fi 

if ! [ $arr_len -gt 1 ]; then
  echo "Less than 2 files supplied.";
  exit $FAILURE;
fi

if [ -z $output_name ]; then
  output_name="output";
fi

if [ -z $out_dir ]; then
  out_dir=".";
fi

ffmpeg_join() {
  ffmpeg -f concat -safe 0 -i temp.txt \
  -hide_banner -loglevel panic -c copy $out_dir/$output_name;
}

ffmpeg_join;

if ! [ -z $cleanup ] && [ $cleanup -eq 1 ]; then
  file_cleanup;
fi

rm -f ./temp.txt;

exit $SUCCESS;