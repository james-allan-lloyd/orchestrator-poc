FROM python:3.11

ADD scripts/pipeline.sh /usr/bin/pipeline.sh
ADD scripts/configure.py /scripts/configure.py
ADD resources resources

RUN chmod +x /usr/bin/pipeline.sh

CMD [ "sh", "-c", "pipeline.sh" ]
ENTRYPOINT []
