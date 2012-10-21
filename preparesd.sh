#!/bin/bash
shopt -s extglob

# Text color variables
txtund=$(tput sgr 0 1)          # Underline
txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) #  red
bldblu=${txtbld}$(tput setaf 4) #  blue
bldgrn=${txtbld}$(tput setaf 2) # green
bldwht=${txtbld}$(tput setaf 7) #  white
txtrst=$(tput sgr0)             # Reset
info=${bldwht}*${txtrst}        # Feedback
pass=${bldblu}*${txtrst}
warn=${bldred}*${txtrst}
ques=${bldblu}?${txtrst}

function print_error {
	echo "${bldred}${1}${txtrst}"
}

function print_drives {

	COUNTER=0

	echo "${bldgrn}The following fixed disks were detected on your machine."

	# build fixed disk selection list
	for mLine in `/bin/egrep '[sh]d[a-z]+$' /proc/partitions`; 
	do   
		if [ `expr $COUNTER % 4` -eq "2" ] ; then
			LASTSIZE=`expr $mLine \* 1024`;
		fi

		if [ `expr $COUNTER % 4` -eq "3" ] ; then

			let bytes=$LASTSIZE;
			let mbsize=`expr $bytes / 1024`;

			printf "%s - %d bytes (%d MB)\n" "$mLine" $bytes $mbsize;
			IDENTIFIER="/dev/$mLine";
			drives[$CHOICE]="$IDENTIFIER";
			sizes[$IDENTIFIER]=$LASTSIZE;

			let CHOICE=CHOICE+1;
		fi

		let COUNTER=COUNTER+1
	done

	echo $txtrst
}

# main script begins below

clear
CHOICE=0

declare -A sizes
drives=()

echo ""
echo "Raspberry Pi SDCard Prepare Script"
echo ""

print_drives

while true; do

	echo "${bldblu}Select a disk to partition${txtrst}"
	#expnd to quoted elements:
	select opt in "${drives[@]}" "quit"; do
  		case ${opt} in
  			(quit) exit; ;;
  			(*) OPTION="${opt}"; echo "${opt}"; INDEX=$REPLY; break; ;;
  		esac;
	done

	CHOICES="${#drives[@]}";

	case "$INDEX" in
		+([0-9])) if [ $INDEX -gt $CHOICES ] || [ $INDEX -lt 1 ]; then echo ""; print_error "Invalid choice"; echo ""; continue; fi ;;
		(*) echo ""; print_error "Invalid choice"; echo ""; continue; ;;
	esac;

	clear

	SELECTEDIDENTIFIER=$OPTION
	echo "${bldwht}You selected $SELECTEDIDENTIFIER${txtrst}"
	echo "${bldblu}Is this correct?"
	echo "${bldred}IMPORTANT:  Data loss will occur if this is incorrect."
	echo "Proceed at your own risk.${txtrst}"
	
	DONE=0
	select opt in "yes" "no" "quit"; do
		case ${opt} in
			(yes) DONE=1; break;;
			(no) break;;
			(quit) exit;;
			(*) echo ""; print_error "Invalid choice"; echo ""; ;;
		esac;
	done


	if [ $DONE -ne 1 ]; then clear; continue;
	fi

	clear

	echo "${bldblu}Are you ABSOLUTELY sure you want to remove all data from the ${bldwht}$SELECTEDIDENTIFIER ${bldblu}drive?${txtrst}"
	echo "${bldred}IMPORTANT:  Data loss will occur if this is incorrect."
	echo "We cannot be held accountable for any damanges or loss resulting from this script."
	echo "Proceed at your own risk.${txtrst}"

	DONE=0
	select opt in "yes" "no" "quit"; do
		case ${opt} in
			(yes) DONE=1; break;;
			(no) break;;
			(quit) exit;;
			(*) echo ""; print_error "Invalid choice"; echo ""; ;;
		esac;
	done

	if [ $DONE -ne 1 ]; then clear; continue;
	else break;
	fi
done

let INDEX=INDEX-1

clear

BYTES=${sizes[$SELECTEDIDENTIFIER]}

HEADS=255
SECTORS=63
CYLINDERS=$(($BYTES/$HEADS/$SECTORS/512))

echo "Clearing Partition Table"
fdisk $SELECTEDIDENTIFIER >/dev/null 2>&1 <<EOF
o
w
EOF

echo "Setting up Paritions"
fdisk $SELECTEDIDENTIFIER >/dev/null 2>&1 <<EOF
x
h
255
s
63
c
$CYLINDERS
r
n
p
1
1
+50
t
c
a
1
n
p
2


w
EOF

echo "Formatting Boot Partition"
mkfs.msdos -F 32 $SELECTEDIDENTIFIER"1" -n BOOTPART >/dev/null

echo "Formatting Linux Partition"
sudo mkfs.ext3 $SELECTEDIDENTIFIER"2" -L LINUXPART >/dev/null

