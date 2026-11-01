FROM nginx:stable-alpine@sha256:0e52bd054126cdc040b1276c0af347aeb02a41b9cfe305d6094767ac30e97949
COPY ci/nginx.conf /etc/nginx/nginx.conf
COPY .ci-dist/frontend/ /usr/share/nginx/html/
EXPOSE 8080
USER nginx
