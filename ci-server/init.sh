#!/bin/bash

# ignore files: init.sh, init-helper.sh

cd $(echo "$(dirname ${BASH_SOURCE[0]})")
source ./init-helper.sh

FILES=$(ls *.sh)
count=$(echo $FILES |awk '{for (i=1;i<=NF-1;i++) printf("%s\n", $i);print $NF}' |wc -l |awk '{print $1}')
i=0
let count=count-2

echo "--- ${i}/${count} update -y ---"
yum update -y
assert_status

for FILE in $FILES; do
	if [[ $FILE = 'init.sh' ]] || [[ $FILE = 'init-helper.sh' ]]; then
		continue
	fi
	let i=i+1
	FILE_NAME=$(echo $FILE |awk -F '/' '{print $NF}' |awk -F '.' '{print $1}')
	echo "--- ${i}/${count} $FILE_NAME installing ---"
	# execute install shell
	bash $FILE
	result=$?
	if [[ $result -eq 0 ]]; then
		echo "--- $FILE_NAME installed ---"
	elif [[ $result -eq 0 ]]; then
		echo "--- $FILE_NAME has already installed ---"
	elif [[ $result -eq 1 ]]; then
		echo ">> error <<<"
		exit 1
	fi
done

if [[ -e final-tips.txt ]]; then
	echo "--- post actions ---"
	cat final-tips.txt
	rm -f final-tips.txt
fi