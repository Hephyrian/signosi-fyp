# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the dependencies file to the working directory
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the content of the local src directory to the working directory
COPY . .

# Make port 8080 available to the world outside this container
EXPOSE 8080

# Define environment variable
ENV GOOGLE_APPLICATION_CREDENTIALS /app/service-account-file.json
# Note: You will need to ensure your service-account-file.json is copied into the image
# or mounted as a volume when running the container. For better security,
# consider managing secrets using Docker secrets or a similar mechanism.

# Run app.py when the container launches
CMD ["python", "app.py"] 