###############################################################################
# Name:         Dockerfile
# Author:       Daniel Middleton <daniel-middleton.com>
# Description:  Dockerfile used to build dannydirect/tinyproxy
# Usage:        docker build -t dannydirect/tinyproxy:latest .
###############################################################################

FROM alpine:latest
ENTRYPOINT ["/opt/docker-tinyproxy/run.sh"]
RUN apk add --update --no-cache \
	bash \
	tinyproxy
COPY run.sh /opt/docker-tinyproxy/run.sh

