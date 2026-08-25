# Backend
# Base Image of Flask
FROM python:3.11-slim

# Environment Python Libraries
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Work Directory of app
WORKDIR /app

# Install MySQL and Cryptography dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc default-libmysqlclient-dev pkg-config curl \
    && rm -rf /var/lib/apt/lists/*

# Copy and Run of requirements.txt 
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Run as non-root user
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

# Expose port of flask 
EXPOSE 5000

# To check the health and cmd of local host
# http://localhost for using local machine and http://<ec2-ip-address> for using AWS EC2 IP Address 
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 \
    CMD curl -f  http://localhost:5000/api/health || exit 1

# CMD to execute of gunicorn and app
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "3", "--timeout", "60", "app:app"]
