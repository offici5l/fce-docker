FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    p7zip-full \
    aria2 \
    git \
    curl \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/vm03/payload_dumper.git /tools \
 && pip install -r /tools/requirements.txt

RUN aria2c -o erofs-utils.zip https://github.com/sekaiacg/erofs-utils/releases/download/v1.8.1-240810/erofs-utils-v1.8.1-gddbed144-Linux_x86_64-2408101422.zip \
 && 7z x erofs-utils.zip -o/tools \
 && rm -f erofs-utils.zip

WORKDIR /workspace
ENV PATH="/tools:${PATH}"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]