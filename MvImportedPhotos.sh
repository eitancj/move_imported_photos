#!/usr/bin/env bash

## Notes ##
# -- This script moves new photos and videos that have been imported today using the 'Photos' mac app, from its "hidden" folders into a new folder on your Desktop, named "Imported_Today'sDate".
# -- This is V2 of the script, that has been updated after upgrading to macOS Catalina (where V1 ceased to work properly)

## Variables ##

WhoIAm=`whoami`
NowDate=`date +%d/%m/%Y`
echo -e "$(tput setaf 14)### Move Imported Media Files — $NowDate ###$(tput sgr0)\n"
NowYear=`date +%Y`
NowMonth=`date +%m`
NowDay=`date +%d`
BaseDir="/Users/$WhoIAm/Pictures/Photos Library.photoslibrary/originals"
#TodayDir="$BaseDir""/$NowYear/$NowMonth/$NowDay"
DestDir="/Users/$WhoIAm/Desktop/Import_$NowDay$NowMonth`date +%y`"
FileList="$DestDir/Files2Move.txt"
TmpLines="$DestDir/TmpLines.txt"
 
## Functions ##

# Cleanup function for removing temporary files & dirs before exiting the script
cleanup () {
	rm -f $FileList 2>/dev/null
	rm -f $TmpLines 2>/dev/null
	rmdir $DestDir 2>/dev/null
	find "$BaseDir" -type d -mtime -1 -depth 1 -empty -delete 2>/dev/null
}

## Main ##

# Verify that an import has been made today
Check2Day=`find "$BaseDir" -type d -mtime -1 -depth 1 2>/dev/null | wc -l`
if [ $? -ne 0 ] || [ $Check2Day -lt 1 ]
then
	echo -e "$(tput setaf 1)No Import Directories from $NowDate could be found at '$BaseDir'.$(tput sgr0)\n"
	exit 999
fi

# Create a list of the imported files to be moved and a destination directory
 	#into which to move them — after verifying such directory doesn't already exist
if [ -d "$DestDir" ]
then
	echo -e "$(tput setaf 1)The destination directory '$DestDir' already exists. Rename, move or delete it, and then try re-running this script.$(tput sgr0)\n"
	exit 999
fi
mkdir $DestDir > /dev/null 2>&1
CountFiles=0
CountBytes=0
rm $FileList > /dev/null 2>&1
touch $FileList
find "$BaseDir" -type d -mtime -1 -depth 1 -exec find {} -type file -ls \; > $TmpLines

# Iterate through all files in today's import folders, and get relevant info
while read -r line ; do
	FSize=`echo $line | awk '{printf $7}'`
	FPath=`echo $line | awk '{for(i=11;i<=NF-1;i++) {printf $i " "}; printf $NF}'`
	FName=`echo $FPath | awk -F "/" '{printf $NF}'`
	((CountFiles++))
	((CountBytes+=$FSize))
	echo "$FPath,$FName,$FSize" >> $FileList
done < $TmpLines

# Calculate Total Size
if [ $CountBytes -lt 1024 ]; then
	TotalSize="$CountBytes Bytes"
elif [ $CountBytes -lt $((1024**2)) ]; then
	TotalSize="$(echo 'scale=2; '$CountBytes '/1024' | bc -l) KB"
elif [ $CountBytes -lt $((1024**3)) ]; then
	TotalSize="$(echo 'scale=2; '$CountBytes '/1024/1024' | bc -l) MB"
elif [ $CountBytes -lt $((1024**4)) ]; then
	TotalSize="$(echo 'scale=2; '$CountBytes '/1024/1024/1024' | bc -l) GB"
elif [ $CountBytes -lt $((1024**5)) ]; then
	TotalSize="$(echo 'scale=2; '$CountBytes '/1024/1024/1024/1024' | bc -l) TB"
else
	TotalSize=$CountBytes
fi

# Promt for user comfirmation before moving the imported files
while true; do 
	echo -e "Are you sure you want to move $(tput setaf 2)$CountFiles$(tput sgr0) files with a total size of $(tput setaf 2)$TotalSize$(tput sgr0) ? [Y/N]"
	read -r -t 300 response
	case $(echo "$response" | awk '{print tolower($0)}') in
		y|yes)
		# Move Files
			SuccessFilesArr=()
			FailFilesArr=()
			SuccessSize=0	
			echo -e "\nMoving files..."
			IFS=$'\n'
			for file in `cat $FileList`; do
				FilePath=`echo $file | awk -F ',' '{print $1}'`
				FileName=`echo $file | awk -F ',' '{print $2}'`
				FileSize=`echo $file | awk -F ',' '{print $3}'` 
				mv -n "$FilePath" "$DestDir" > /dev/null 2>&1
				if [ $? -eq 0 ]
				then
					echo "$(tput setaf 2)$FileName$(tput sgr0) $FileSize"
					SuccessFilesArr+=("$FileName")
					((SuccessSize+=$FileSize))
				else
					echo "$(tput setaf 1)$FileName$(tput sgr0) $FileSize"
					FailFilesArr+=("$FileName")
				fi
			done
			tput sgr0
			echo ""
			SuccessfulFilesCount=${#SuccessFilesArr[@]}
			FailedFilesCount=${#FailFilesArr[@]}
			break
		;;
		n|no)
		# Quit program without moving files
			echo -e "\nNo files were moved.\n"
			cleanup
			exit 0
		;;
		*)
		# Re-Prompt user for confirmation
	esac
done

# Summarize Results
echo "New imported-files Path: '$DestDir'"
echo "Successful-files Count: $SuccessfulFilesCount"
echo "Successful-files Total Bytes: $SuccessSize"
echo "Failed-files Count: $FailedFilesCount"
if [ $FailedFilesCount -ne 0 ]
then  
	echo "Failed-files List:"
	for FailedFile in ${FailedFilesArr[*]}
	do
		echo $FailedFile
	done
fi

# Clean up b4 exiting
cleanup
tput sgr0
echo ""