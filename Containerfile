FROM registry.access.redhat.com/ubi9/ubi-minimal

# Point to the default path used by cachi2-playground. For koflux
# this is /cachi2/output/deps/generic/
ARG CRATES_PATH="/tmp/output/deps/generic"

WORKDIR /app
ARG BUILD_PACKAGES="cargo gcc libffi-devel python3.12-devel"
RUN microdnf install \
    python3.12 \
    ${BUILD_PACKAGES} \
    -y && \
    python3.12 -m venv .venv
ENV PATH="/app/.venv/bin:${PATH}"

COPY prepare-rust-deps.py .
RUN python prepare-rust-deps.py "${CRATES_PATH}"

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["python", "hello.py"]
