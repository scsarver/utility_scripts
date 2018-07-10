#!/usr/bin/env bash
#
# Created By: stephansarver
# Created Date: 20180629-084430
#
# Referenced: https://stackoverflow.com/questions/18069611/fastest-way-of-finding-differences-between-two-files-in-unix

set -o errexit
set -o nounset

FILE1="file-1.txt"
FILE2="file-2.txt"
ADDED_RESULT_FILE="to-add-results.txt"
REMOVED_RESULT_FILE="to-remove-result.txt"

echo "Added"
join -v 2 <(sort $FILE1) <(sort $FILE2) > $ADDED_RESULT_FILE
cat $ADDED_RESULT_FILE

diff $FILE1 $FILE2 | grep "<" | sed 's/^<//g'  > $REMOVED_RESULT_FILE
echo "Removed:"
cat $REMOVED_RESULT_FILE
