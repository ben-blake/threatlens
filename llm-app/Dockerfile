# Use an official lightweight Python image
FROM python:3.9-slim

# Set the working directory to /app
WORKDIR /app

# Prevent Python from writing .pyc files
ENV PYTHONDONTWRITEBYTECODE 1
# Ensure Python output is sent directly to the terminal without buffering
ENV PYTHONUNBUFFERED 1

# Copy the requirements file into the container
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code into the container
COPY . .

# The PORT environment variable is set by Cloud Run. Default to 8080 for local testing.
ENV PORT 8080

# Use gunicorn to run the application.
# It will listen on all available network interfaces at the port specified by $PORT.
# The 'exec' command ensures that gunicorn is the main process.
CMD exec gunicorn --bind 0.0.0.0:$PORT --workers 1 --threads 8 --timeout 0 main:app 