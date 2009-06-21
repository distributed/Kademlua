#!/bin/bash

# start.sh
# (C) 2009, Michael Meier

nums="1 2 3 4"


min=8003
max=8102
# glorious mac os x does not offer a seq command, so here we go...
counter=$min
while [ $counter -le $max ]; do
#    echo $counter
    sn="$sn $counter"
    counter=$(expr $counter + 1)
done


#sn="8003 8004 8005 8006 8007 8008 8009 8010"
#sn="8012"

cleanup() {
    for pid in $pids; do
	echo $pid
	# how rude
	kill -9 $pid
    done;

    exit 0
}

trap cleanup SIGINT SIGTERM

for n in $sn; do
    ./kademlua $n > log/$n &
    #sleep 1$n &
    sleep 0.1
    echo started kademlua with port number $n
    npid=$!
    pids="$pids $npid"
done


sleep 0.2
for port in $sn; do
    echo -n $port " : "
    echo -n $port | sha1sum | cut -d " " -f 1
done

while :
do
    sleep 60
done

