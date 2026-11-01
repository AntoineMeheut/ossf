FROM python:3.14.7-slim-trixie AS install
WORKDIR /install
COPY wheelhouse/ /wheels/
COPY requirements.txt .
COPY .ci-dist/wheels/ /application/
RUN pip install --no-index --find-links=/wheels --prefix=/install -r requirements.txt \
    && pip install --no-index --no-deps --prefix=/install /application/*.whl

FROM python:3.14.7-slim-trixie
ARG PYTHON_MODULE=app
ENV PYTHON_MODULE=${PYTHON_MODULE} PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY --from=install /install/ /usr/local/
COPY ci/entrypoint.sh /usr/local/bin/application-entrypoint
USER 10001:10001
ENTRYPOINT ["sh", "/usr/local/bin/application-entrypoint"]
