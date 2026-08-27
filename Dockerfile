# Use official lightweight Python image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all project code
COPY . .

# Expose Flask default port
EXPOSE 5000

# Start Flask app using gunicorn for production stability
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
