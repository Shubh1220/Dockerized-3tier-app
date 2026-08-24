# Frontend 
# Base Image of Nginx
FROM nginx:1.30.1-alpine

# Remove conf.d and drop our files
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy of html, css and js to nginx 
COPY index.html style.css app.js /usr/share/nginx/html/

# Expose port of nginx
EXPOSE 80

# To check health and cmd of localhost
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 \
     CMD wget -qO- http://localhost:80/ || exit 1

# CMD to execute the nginx
CMD ["nginx", "-g", "daemon off;"] 
