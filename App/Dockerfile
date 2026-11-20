# Use Python as the base environment
FROM python:3.11-slim

# Set the working directory inside the container
WORKDIR /app

# Copy application dependencies
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Tell Docker which port the application uses
EXPOSE 8000

# Start the FastAPI application
CMD ["uvicorn", "Main:app", "--host", "0.0.0.0", "--port", "8000"]