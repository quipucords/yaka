FROM registry.access.redhat.com/ubi9/ubi-minimal

WORKDIR /app
ARG BUILD_PACKAGES="gcc libffi-devel python3.12-devel"
RUN microdnf install \
    python3.12 \
    ${BUILD_PACKAGES} \
    -y && \
    python3.12 -m venv .venv
ENV PATH="/app/.venv/bin:${PATH}"

COPY requirements.txt .
RUN pip install -r requirements.txt
RUN microdnf remove ${BUILD_PACKAGES} -y && \
    microdnf clean all

COPY . .

CMD ["python", "hello.py"]
