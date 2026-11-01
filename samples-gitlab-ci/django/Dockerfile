FROM python:3.14.7-slim-trixie
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --no-create-home app
COPY manage.py .
COPY surfnews/ surfnews/
COPY news/ news/
USER 10001
EXPOSE 8000
CMD ["gunicorn", "surfnews.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-"]
