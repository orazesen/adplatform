start: build-user-management-image
	kubectl apply -f k8s/namespace.yaml 
	kubectl apply -f k8s/

stop:
	kubectl delete namespace adplatform

build-user-management-image:
	docker build -t orazesen/user-management:latest -f user-management/Dockerfile user-management