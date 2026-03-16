FROM haproxy:3.2-alpine

USER root
RUN apk add --no-cache gettext

COPY lua/ /etc/haproxy/lua/
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER haproxy
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["haproxy", "-W", "-db", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
