#!/bin/bash

while true; do {
	echo "$(date +%F\ %X): $(pueue status | grep -e 'Queued' -e 'Running' | wc -l)"
	sleep 10
}
done
