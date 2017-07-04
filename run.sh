#!/bin/bash

# Global vars
PROG_NAME='DockerTinyproxy'
PROXY_DEFAULT_CONF='/etc/tinyproxy/tinyproxy.conf'
PROXY_CONF='/tmp/tinyproxy.conf'
TAIL_LOG='/var/log/tinyproxy/tinyproxy.log'

# Usage: screenOut STATUS message
screenOut() {
    timestamp=$(date +"%H:%M:%S")

    if [ "$#" -ne 2 ]; then
        status='INFO'
        message="$1"
    else
        status="$1"
        message="$2"
    fi

    echo -e "[$PROG_NAME][$status][$timestamp]: $message"
}

# Usage: checkStatus $? "Error message" "Success message"
checkStatus() {
    case $1 in
        0)
            screenOut "SUCCESS" "$3"
            ;;
        1)
            screenOut "ERROR" "$2 - Exiting..."
            exit 1
            ;;
        *)
            screenOut "ERROR" "Unrecognised return code."
            ;;
    esac
}

displayUsage() {
    echo
    echo '  Usage:'
    echo "      docker run -d --name='proxy' -p <Host_Port>:8888 dannydirect/tinyproxy:latest -u <UPSTREAM> -l <LOCAL_MICRO_SERVICE1> -l <LOCAL_MICRO_SERVICE2>"
    echo
    echo "      - Set <Host_Port> to the port you wish the proxy to be accessible from."
    echo "      - Set <UPSTREAM> to dev proxy of int proxy"
    echo "      - Set <LOCAL_MICRO_SERVICE*> to short_service_name=ip"
    echo
}

stopService() {
    screenOut "Checking for running Tinyproxy service..."
    if [ "$(pidof tinyproxy)" ]; then
        screenOut "Found. Stopping Tinyproxy service for pre-configuration..."
        killall tinyproxy
        checkStatus $? "Could not stop Tinyproxy service." \
                       "Tinyproxy service stopped successfully."
    else
        screenOut "Tinyproxy service not running."
    fi
}

parseAccessRules() {
    list=''
    for ARG in $@; do
        line="Allow\t$ARG\n"
        list+=$line
    done
    echo "$list" | sed 's/.\{2\}$//'
}

setMiscConfig() {
    sed -i -e"s,^MinSpareServers ,MinSpareServers\t1 ," ${PROXY_CONF}
    checkStatus $? "Set MinSpareServers - Could not edit ${PROXY_CONF}" \
                   "Set MinSpareServers - Edited ${PROXY_CONF} successfully."

    sed -i -e"s,^MaxSpareServers ,MaxSpareServers\t1 ," ${PROXY_CONF}
    checkStatus $? "Set MinSpareServers - Could not edit ${PROXY_CONF}" \
                   "Set MinSpareServers - Edited ${PROXY_CONF} successfully."

    sed -i -e"s,^StartServers ,StartServers\t1 ," ${PROXY_CONF}
    checkStatus $? "Set MinSpareServers - Could not edit ${PROXY_CONF}" \
                   "Set MinSpareServers - Edited ${PROXY_CONF} successfully."
}

enableLogFile() {
	touch /var/log/tinyproxy/tinyproxy.log
	sed -i -e"s,^#LogFile,LogFile," ${PROXY_CONF}
}

setAccess() {
    sed -i -e"s/^Allow /#Allow /" ${PROXY_CONF}
    checkStatus $? "Allowing ANY - Could not edit ${PROXY_CONF}" \
                   "Allowed ANY - Edited ${PROXY_CONF} successfully."
}

startService() {
    screenOut "Starting Tinyproxy service..."
    /usr/sbin/tinyproxy -c ${PROXY_CONF}
    checkStatus $? "Could not start Tinyproxy service." \
                   "Tinyproxy service started successfully."
}

tailLog() {
    screenOut "Tailing Tinyproxy log..."
    tail -f $TAIL_LOG
    checkStatus $? "Could not tail $TAIL_LOG" \
                   "Stopped tailing $TAIL_LOG"
}

addUpstreamServer() {
  echo "upstream $1" >> "${PROXY_CONF}"
}

addLocalServive() {
  echo "no upstream \"${1}\"" >> "${PROXY_CONF}"
  if [[ "${2}" = "${1}" ]]; then
    echo "127.0.0.1 ${1}" >> /etc/hosts
  else
    echo "${2} ${1}" >> /etc/hosts
  fi
}

# Check args
if [ "$#" -lt 1 ]; then
    displayUsage
    exit 1
fi

# Init configuration
cp "${PROXY_DEFAULT_CONF}" "${PROXY_CONF}"
# Start script
echo && screenOut "$PROG_NAME script started..."
# Stop Tinyproxy if running
stopService
# Set ACL in Tinyproxy config
setAccess
# Enable log to file
enableLogFile

while getopts ":u:l:" opt; do
  case $opt in
    u)
      echo "Addding upstream server $OPTARG" >&2
      addUpstreamServer $OPTARG
      ;;
    l)
      name=${OPTARG%%=*}
      value=${OPTARG##*=}
      ip=${value%%:*}
      port=${value##*:}
      echo "Add exception for ${name} to ${value}" >&2
      addLocalServive ${name} ${ip} ${port}
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Show effective configuration
grep -v "#" ${PROXY_CONF} | grep -v -e '^[[:space:]]*$'
cat /etc/hosts

# Start Tinyproxy
startService
# Tail Tinyproxy log
tailLog & wait ${!}
# End
screenOut "$PROG_NAME script ended." && echo
exit 0
