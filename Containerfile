# build in multiple stages so cleanup of transitive dependencies is easier
FROM registry.access.redhat.com/ubi9/ubi-minimal as builder
# Point to the default path used by cachi2-playground. For koflux
# this is /cachi2/output/deps/generic/
ARG CRATES_PATH="/tmp/output/deps/generic"

WORKDIR /app
RUN microdnf install \
    cargo \
    gcc \
    libffi-devel \
    openssl-devel \
    python3.12-devel \
    python3.12 \
    -y && \
    python3.12 -m venv /venv
ENV PATH="/venv/bin:${PATH}"
COPY prepare-rust-deps.py .
RUN python prepare-rust-deps.py "${CRATES_PATH}"

COPY lockfiles/requirements.txt .
RUN pip install --verbose -r requirements.txt

# final stage
FROM registry.access.redhat.com/ubi9/ubi-minimal
RUN microdnf install -y python3.12
COPY --from=builder /venv /venv
WORKDIR /app
COPY hello.py key.txt message.txt .
ENV PATH="/venv/bin:${PATH}"

CMD ["python", "hello.py"]
