FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 5000

# Non-root user for security (Prinsip IDEAL: Isolated)
RUN adduser --disabled-password --gecos '' appuser
USER appuser

CMD ["python", "app.py"]
