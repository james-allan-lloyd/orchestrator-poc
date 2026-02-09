FROM python:3.11

RUN pip install git+https://github.com/syntasso/kratix-python.git

COPY scripts /scripts

RUN chmod +x /scripts/configure.py

CMD ["python3", "/scripts/configure.py"]
ENTRYPOINT []
