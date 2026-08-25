# Nginx
# Base Image of Nginx
FROM nginx:1.30.1-alpine

# Remove conf.d and drop our files
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port of nginx
EXPOSE 80

# To check health and cmd of localhost
# http://localhost for using local machine and http://<ec2-ip-address> for using AWS EC2 IP Address
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 \
   CMD wget -qO- http://localhost:80/healthz/ || exit 1

# CMD to execute the nginx
CMD ["nginx", "-g", "daemon off;"]
