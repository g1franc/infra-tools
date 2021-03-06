#!/bin/bash

# Set up a default search path
PATH="/usr/bin:/bin"

CURL=`which curl`
if [ -z "$CURL" ]; then
	echo "curl not found"
	exit 1
fi

server="localhost"
port="80"
manager="balancer-manager"
protocol="${protocol}"
curl_parameters=""

# Note: There is a "nonce" by balancer
# Note: It seems a balancer CAN be listed more than once, maybe a configuration issue !?

while getopts "s:p:m:t:c:" opt; do
	case "$opt" in
		s)
			server=$OPTARG
			;;
		p)
			port=$OPTARG
			;;
		m)
			manager=$OPTARG
			;;
		t)
			protocol=$OPTARG
			;;
		c)
			curl_parameters=$OPTARG
			;;
	esac
done

shift $(($OPTIND - 1))
action=$1

list_balancers() {
	$CURL ${curl_parameters} -s "${protocol}://${server}:${port}/${manager}" | grep "balancer://" | sed "s/.*balancer:\/\/\(.*\)<\/a>.*/\1/"
}

list_workers() {
	balancer=$1
	if [ -z "$balancer" ]; then
		echo "Usage: $0 [-s host] [-p port] [-m balancer-manager] list-workers balancer_name"
		echo "balancer_name : balancer name"
		exit 1
	fi	
	$CURL ${curl_parameters} -s "${protocol}://${server}:${port}/${manager}" | grep "/balancer-manager?b=${balancer}&w" | sed "s/.*href='\(.[^']*\).*/\1/" | sed "s/.*w=\(.*\)&.*/\1/"
}

enable() {
	balancer=$1
	worker=$2
	if [ -z "$balancer" ] || [ -z "$worker" ]; then
		echo "Usage: $0 [-s host] [-p port] [-m balancer-manager] enable balancer_name worker_route"
		echo " balancer_name : balancer/cluster name"
		echo " worker_route : worker route e.g.) ajp://192.1.2.3:8009"
		exit 1
	fi
	
	nonce=`$CURL ${curl_parameters} -s "${protocol}://${server}:${port}/${manager}" | grep nonce | grep "${balancer}</a>" | sed "s/.*nonce=\(.*\)['\"].*/\1/" | tail -n 1`
	if [ -z "$nonce" ]; then
		echo "balancer_name ($balancer) not found"
		exit 1
	fi

	echo "Enabling $2 of $1..."
	# Apache 2.2.x
	#$CURL ${curl_parameters} -s -o /dev/null -XPOST "${protocol}://${server}:${port}/${manager}?" -d b="${balancer}" -d w="${worker}" -d nonce="${nonce}" -d dw=Enable
	$CURL ${curl_parameters} -s -o /dev/null -XPOST "${protocol}://${server}:${port}/${manager}?" -d b="${balancer}" -d w="${worker}" -d nonce="${nonce}" -d w_status_D=0
}

disable() {
	balancer=$1
	worker=$2
	if [ -z "$balancer" ] || [ -z "$worker" ]; then
		echo "Usage: $0 [-s host] [-p port] [-m balancer-manager] disable balancer_name worker_route"
		echo " balancer_name : balancer/cluster name"
		echo " worker_route : worker route e.g.) ajp://192.1.2.3:8009"
		exit 1
	fi
	
	echo "Disabling $2 of $1..."
	nonce=`$CURL ${curl_parameters} -s "${protocol}://${server}:${port}/${manager}" | grep nonce | grep "${balancer}</a>" | sed "s/.*nonce=\(.*\)['\"].*/\1/" | tail -n 1`
	if [ -z "$nonce" ]; then
		echo "balancer_name ($balancer) not found"
		exit 1
	fi

	# Apache 2.2.x
	#$CURL ${curl_parameters} -s -o /dev/null -XPOST "${protocol}://${server}:${port}/${manager}?" -d b="${balancer}" -d w="${worker}" -d nonce="${nonce}" -d dw=Disable
	$CURL ${curl_parameters} -s -o /dev/null -XPOST "${protocol}://${server}:${port}/${manager}?" -d b="${balancer}" -d w="${worker}" -d nonce="${nonce}" -d w_status_D=1
}

status() {
	$CURL ${curl_parameters} -s "${protocol}://${server}:${port}/${manager}" | grep "href" | sed "s/<[^>]*>/ /g"
}

debug () {
	echo "server |${server}|"
	echo "port |${port}|"
	echo "manager |${manager}|"
	echo "protocol |${protocol}|"
	echo "curl_parameters |${server}|"
	echo "nonce |${nonce}|"
	echo "balancer |${balancer}|"
	echo "worker |${worker}|"
	echo "arg1 |$1|"
	echo "arg2 |$2|"
}

case "$1" in
	list-balancer)
		list_balancers "${@:2}"
	;;
	list-worker)
		list_workers "${@:2}"
	;;
	enable)
		enable "${@:2}"
	;;
	disable)
		disable "${@:2}"
	;;
	status)
		status "${@:2}"
	;;
	*)
		echo "Usage: $0 {list-balancer|list-worker|enable|disable|status}"
		echo ""
		echo "Options: "
		echo " -s server"
		echo " -p port"
		echo " -m balancer-manager-context-path"
		echo " -t protocol (http|https)"
		echo "-c CURL parameter like --insecure"
		echo ""
		echo "Commands: "
		echo " list-balancer"
		echo " list-worker balancer-name"
		echo " enable balancer_name worker_route"
		echo " disable balancer_name worker_route"
		exit 1
esac
