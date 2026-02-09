echo "📦 Installing Team Promise..."

docker build -t team-configure promises/team-promise/workflows/resource/configure/team-configure/python
kind load docker-image -n kratix-poc localhost/team-configure:latest

# Install the Team Promise
kubectl apply -f promises/team-promise/promise.yaml
