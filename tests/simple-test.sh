#!/usr/bin/env bash
###############################################
#                                             #
# First simple test script for ACME-DNS-NC.   #
# Try to add and delete 100 random records.   #
#                                             #
# Use --wildcard to test the new (ACMEv2)     #
# handling with multiple records per host.    #
#                                             #
# Example: simple-test.sh --wildcard \        #
#            example.org root-dns.netcup.net  #
#                                             #
###############################################

set -euf -o pipefail
cd "$(dirname "$(readlink -f "$0")")"

if [[ "${1-}" == "--wildcard" ]]
then V2=1; shift; else V2=0; fi

DOMAIN=${1-}; NS=${2-DEFAULT}
SCRIPT=${3-../scripts/acme-dns-nc}
WAIT_TRIES=100; WAIT_DNS=12; WAIT_NEXT=5
CHALLENGE_PREFIX="_acme-challenge"

if [[ "$DOMAIN" == "" ]]; then echo "Usage: $0 [--wildcard] <domain> [<primary-nameserver> [<path-to-script>]]" 1>&2; exit 1
elif [[ ! -x "$SCRIPT" ]]; then echo "Invalid path to script: $SCRIPT" 1>&2; exit 1; fi
if [[ "$NS" == "DEFAULT" ]]; then NS=; else NS="@$NS"; fi

tmpfile=`mktemp`; logfile=`mktemp`
echo "Logfile for errors: ${logfile}"

function status
{
	pre=${1-UNKNOWN}; msg=${2-}; ext=${3-}
	if [[ "$ext" != "" ]]; then ext=": $ext"; fi
	echo -ne "\r$(date +%H:%M:%S) [$pre] $msg$ext"
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

for i in {1..100}
do
	# \n
	echo

	# Get random values for hostname and TXT record data.
	hostname="test-$(printf '%05d' "$RANDOM")-$(printf '%05d' "$RANDOM").$DOMAIN"
	txtvalue="test-$RANDOM-$RANDOM-$RANDOM-$(date +%Y%m%d-%H%M%S)"

	# Try to add the DNS record.
	status "${YELLOW}ADD RR${RESET}" "$hostname"

	return=0
	if [[ -n "$V2" ]]
	then
		"$SCRIPT" --add "$hostname" "$txtvalue-1" 1>/dev/null 2>>"$logfile" && \
		"$SCRIPT" --add "$hostname" "$txtvalue-2" 1>/dev/null 2>>"$logfile" || \
		return=$? && :
	else
		"$SCRIPT" "$hostname" "$txtvalue" 1>/dev/null 2>>"$logfile" || return=$? && :
	fi

	if [[ "$return" != "0" ]]
	then
		status "${RED}ADD RR${RESET}" "$hostname" "Failed!  (could not create or update DNS-RR)"
		continue
	fi

	final=-1
	for((w=1; w<=WAIT_TRIES; w++))
	do
		# Wait for the primary NS to update its zone...
		status "${YELLOW}WAIT#1${RESET}" "$hostname" "($w/$WAIT_TRIES)                             "
		sleep "$WAIT_DNS"

		# Check the DNS record.
		status "${YELLOW}CHK #1${RESET}" "$hostname"
		return=0; dig +short "TXT" "$CHALLENGE_PREFIX.$hostname" "$NS" 1>"$tmpfile" 2>/dev/null || return=$? && :

		result=0
		if [[ -n "$V2" ]]
		then
			while IFS='' read -r line || [[ -n "$line" ]]
			do
				if [[ "$line" == "\"$txtvalue-1\"" ]];   then ((result+=1))
				elif [[ "$line" == "\"$txtvalue-2\"" ]]; then ((result+=2))
				else ((result+=10)); fi
			done < "$tmpfile"
		elif [[ "$(cat "$tmpfile")" == "\"$txtvalue\"" ]]
		then
			result=3;
		fi

		if [[ "$return" == "0" && "$result" -eq 3 ]]
		then final=0; break; else final=1; fi
	done

	if [[ "$final" != "0" ]]
	then
		status "${RED}CHK #1${RESET}" "$hostname" "Failed!  (value not found in DNS)"
		continue
	fi

	# Try to delete the DNS record.
	status "${YELLOW}DEL RR${RESET}" "$hostname"

	return=0
	if [[ -n "$V2" ]]
	then
		"$SCRIPT" --del "$hostname" "$txtvalue-1" 1>/dev/null 2>>"$logfile" && \
		"$SCRIPT" --del "$hostname" "$txtvalue-2" 1>/dev/null 2>>"$logfile" || \
		return=$? && :
	else
		"$SCRIPT" "$hostname" 1>/dev/null 2>>"$logfile" || return=$? && :
	fi

	if [[ "$return" != "0" ]]
	then
		status "${RED}DEL RR${RESET}" "$hostname" "Failed!  (could not delete DNS-RR)"
		continue
	fi

	final=-1
	for((w=1; w<=WAIT_TRIES; w++))
	do
		# Wait for the DNS cache to expire...
		status "${YELLOW}WAIT#2${RESET}" "$hostname" "($w/$WAIT_TRIES)                             "
		sleep "$WAIT_DNS"

		# Check the DNS record.
		status "${YELLOW}CHK #2${RESET}" "$hostname"
		return=0; dig +short "TXT" "$CHALLENGE_PREFIX.$hostname" "${NS}" 1>"$tmpfile" 2>/dev/null || return=$? && :

		if [[ "$return" == "0" && "$(cat "$tmpfile")" == "" ]]
		then final=0; break; else final=1; fi
	done

	if [[ "$final" != "0" ]]
	then
		status "${RED}CHK #2${RESET}" "$hostname" "Failed!  (record still exists)"
		continue
	fi

	# Wait for the next test run...
	status "${GREEN}  OK  ${RESET}" "$hostname" "Success!                          "
	sleep "$WAIT_NEXT"

done

if [[ "0$(stat --printf="%s" "$logfile")" == "00" ]]
then
	echo -e "\n\nDeleting empty logfile: $logfile"
	rm -f "$logfile"
else
	echo -e "\n\nLogfile is not empty: $logfile"
fi

rm -f "$tmpfile"
