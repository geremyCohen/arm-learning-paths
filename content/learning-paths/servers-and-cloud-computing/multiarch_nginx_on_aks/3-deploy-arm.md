---
title: Deploy nginx ARM to the cluster
weight: 50

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Add ARM deployment and service

In this section, you'll add nginx on ARM nodes to your existing cluster, completing your multi-architecture Intel/ARM environment for comprehensive performance comparison.

The **arm_nginx.yaml** file creates the following K8s objects:
   - **ConfigMap** (`nginx-arm-config`) - Contains performance-optimized nginx configuration with ARM-specific tuning
   - **Deployment** (`nginx-arm-deployment`) - Pulls the multi-architecture nginx image from DockerHub, launches a pod on the ARM node, and mounts the ConfigMap as `/etc/nginx/nginx.conf`
   - **Service** (`nginx-arm-svc`) - Load balancer targeting pods with both `app: nginx-multiarch` and `arch: arm` labels

Copy and paste the following commands into a terminal to download and apply the ARM deployment and service:

```bash
curl -o arm_nginx.yaml https://raw.githubusercontent.com/geremyCohen/nginxOnAKS/refs/heads/main/arm_nginx.yaml
kubectl apply -f arm_nginx.yaml
```

You will see output similar to:

```output
configmap/nginx-arm-config created
deployment.apps/nginx-arm-deployment created
service/nginx-arm-svc created
```

### Examining the deployment configuration

Taking a closer look at the `arm_nginx.yaml` deployment file, you'll see settings optimized for ARM architecture:

* The `nodeSelector` `kubernetes.io/arch: arm64`. This ensures that the deployment only runs on ARM nodes, utilizing the arm64 version of the nginx container image.

```yaml
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64
```

* The service selector uses both `app: nginx-multiarch` and `arch: arm` labels to target only ARM pods. This dual-label approach allows for both architecture-specific and multi-architecture service routing.

```yaml
  selector:
    app: nginx-multiarch
    arch: arm
```

* The ARM ConfigMap includes performance optimizations specific to ARM architecture, such as `worker_processes 2` and `worker_cpu_affinity 01 10` for optimal CPU core utilization.

### Verify the deployment

### Verify the deployment

1. Get the status of nodes, pods and services by running:

```bash
kubectl get nodes,pods,svc -nnginx 
```

Your output should be similar to the following, showing two nodes, two pods, and two services:

```output
NAME                                 STATUS   ROLES    AGE   VERSION
node/aks-arm-56500727-vmss000000     Ready    <none>   59m   v1.32.7
node/aks-intel-31372303-vmss000000   Ready    <none>   63m   v1.32.7

NAME                                          READY   STATUS    RESTARTS   AGE
pod/nginx-arm-deployment-5bf8df95db-wznff     1/1     Running   0          36s
pod/nginx-intel-deployment-78bb8885fd-mw24f   1/1     Running   0          9m21s

NAME                      TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)        AGE
service/nginx-arm-svc     LoadBalancer   10.0.241.154   48.192.64.197   80:30082/TCP   36s
service/nginx-intel-svc   LoadBalancer   10.0.226.250   20.80.128.191   80:30080/TCP   9m22s
```

You can also verify the ConfigMap was created:

```bash
kubectl get configmap -nnginx
```

```output
NAME                 DATA   AGE
nginx-arm-config     1      51s
nginx-intel-config   1      10m
```

When the pods show `Running` and the service shows a valid `External IP`, you're ready to test the nginx ARM service.

### Test the nginx web service on ARM

2. Run the following to make an HTTP request to the ARM nginx service using the script you created earlier:

```bash
./nginx_util.sh get arm
```

You get back the HTTP response, as well as information about which pod served it:

```output
Using service endpoint 48.192.64.197 for get on arm service
Response:
{
  "message": "nginx response",
  "timestamp": "2025-10-24T22:04:59+00:00",
  "server": "nginx-arm-deployment-5bf8df95db-wznff",
  "request_uri": "/"
}
Served by: nginx-arm-deployment-5bf8df95db-wznff
```

If you see output similar to above, you have successfully added ARM nodes to your cluster running nginx.

### Compare both architectures

Now you can test both architectures and compare their responses:

```bash
./nginx_util.sh get intel
./nginx_util.sh get arm
```

Each command will route to its respective architecture-specific service, allowing you to compare performance and verify that your multi-architecture cluster is working correctly.
