FROM registry.access.redhat.com/ubi9/ubi-minimal

WORKDIR /app
RUN microdnf install -y python3.12 && \
    python3.12 -m venv .venv
ENV PATH="/app/.venv/bin:${PATH}"

COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .

CMD ["python", "hello.py"]
