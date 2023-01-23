all:
	docker build --pull -t wyga/lsyncd:v1 -f Dockerfile.ubuntu .
	docker push wyga/lsyncd:v1
