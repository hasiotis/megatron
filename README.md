## Playing around with kubernetes and uniconv

Everybody know who the [enemy](https://en.wikipedia.org/wiki/Megatron) of [optimus prime](https://en.wikipedia.org/wiki/Optimus_Prime) is! 

Make sure you have minikube setup with freshpod, localhost insecure registry and ingress addon
```
minikube start --insecure-registry=localhost:5000
minikube addons enable ingress
minikube addons enable freshpod
```

Create the docker image (directly on minikube)
```
eval $(minikube docker-env)
docker build -t megatron:1.0.0 .
```

Deploy on minikube:
```
kubectl apply -f minikube/
```

Check that it works:
```
echo "$(minikube ip) megatron" | sudo tee -a /etc/hosts
curl -s http://file-examples.com/wp-content/uploads/2017/02/file-sample_1MB.docx > /tmp/sample.docx
curl -s --form file=@/tmp/sample.docx http://megatron/unoconv/pdf/ > sample.pdf
curl -s --form file=@/tmp/sample.docx http://megatron/unoconv/txt/ > sample.txt
```

Scale the thing
```
kubectl scale deployment megatron --replicas=5
```

We glue together the following projects:

* https://github.com/dagwieers/unoconv
* https://github.com/jordanorc/docker-unoconv-flask
