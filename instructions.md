# Building the Docker image
docker-compose build
# Run the container in the background
docker-compose up -d
# Grab the container ID
docker ps
# Run interactive shell
docker exec -it <dockerID> /bin/sh
# Test if config is copied
ls /etc/
# Local cleanup
docker-compose down --volume

# Azure setup -> push image to a newly created ACR
docker login solaracr.azurecr.io
docker tag strm/dnsmasq solaracr.azurecr.io/dnsmasq
docker push solaracr.azurecr.io/dnsmasq