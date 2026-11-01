FROM python:3.14.7-slim-trixie
ARG DJANGO_WSGI_MODULE=config.wsgi:application
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 DJANGO_WSGI_MODULE=${DJANGO_WSGI_MODULE}
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --no-create-home app
# Includes arbitrary app packages, templates and static files; review .dockerignore.
COPY . .
USER 10001
EXPOSE 8000
CMD ["sh", "-c", "exec gunicorn \"$DJANGO_WSGI_MODULE\" --bind 0.0.0.0:8000 --workers 2 --access-logfile -"]
