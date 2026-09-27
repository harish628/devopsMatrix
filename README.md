# devopsMatrix

## Deploy to EKS

The Kubernetes manifests are shared across CI systems. For Jenkins, CodeBuild/CodePipeline, or GitHub Actions, configure AWS credentials on the runner and invoke the same deploy script after pushing the image to ECR:

```sh
AWS_REGION=ap-south-1 \
EKS_CLUSTER=eksCluster \
IMAGE_URI=123456789012.dkr.ecr.ap-south-1.amazonaws.com/static-site:42 \
sh EKS/kubernetes/deploy.sh
```

`IMAGE_URI` must be the complete, pushed image reference. The EKS cluster and worker nodes must already exist. The runner needs AWS CLI, `kubectl`, access to the EKS cluster, and permission to update kubeconfig. The script applies `namespace.yaml`, then `deployment.yaml` with the supplied image, then `service.yaml`; it waits for the Deployment and LoadBalancer and prints the service details. The application namespace is `static-site` in the manifests.

In Jenkins, call `sh 'sh EKS/kubernetes/deploy.sh'` with `AWS_REGION`, `EKS_CLUSTER`, and `IMAGE_URI` in the build environment. In CodeBuild, add `sh EKS/kubernetes/deploy.sh` after the image push, with those same variables in the build environment. In a GitHub Actions step, use `run: sh EKS/kubernetes/deploy.sh` after configuring AWS credentials and setting those variables.

## Argo CD

The `EKS/kubernetes` directory has a Kustomize entry point. Create an Argo CD Application pointing to that path and set its Kustomize namespace to `static-site`. Since Argo CD does not run the CI shell script, configure the Application's Kustomize image override to a real ECR image, for example:

```yaml
source:
  path: EKS/kubernetes
  kustomize:
    namespace: static-site
    images:
      - placeholder/static-site=123456789012.dkr.ecr.ap-south-1.amazonaws.com/static-site:42
```

The resource sync-wave annotations order Argo CD syncs as Namespace, Deployment, then Service. Configure the Application's destination to the EKS cluster registered in Argo CD; its Argo CD cluster name may be set to `eksCluster`. For GitOps, update the Application image override (or a Kustomize overlay) when publishing a new image so Argo CD can sync that tag.