# ใช้ Official Python image
FROM python:3.13-slim

# กำหนด working directory
WORKDIR /app

# ติดตั้ง dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy โค้ดทั้งหมด
COPY . .

# expose port
EXPOSE 5000

# default command
CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]