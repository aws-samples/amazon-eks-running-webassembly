# Run WebAssembly workloads on Amazon EKS

This repository contains code for building a custom Amazon EKS AMI using [HashiCorp Packer](https://www.packer.io/).
The AMI includes necessary binaries and configurations to enable you to run WebAssembly workloads in an EKS cluster and is based on Amazon Linux 2023. The runtimes used in this AMI are [Spin](https://github.com/fermyon/spin) and [WasmEdge](https://github.com/WasmEdge/WasmEdge). The respective containerd-shims are used for both runtimes.
Deploying the cluster is done using [Hashicorp Terraform](https://www.terraform.io/).
After the cluster is created, RuntimeClasses and example workloads are deployed to the cluster.

> **Note**
> The code in this repository provides you with a sample to demonstrate how to run WebAssembly workloads on Amazon EKS.
> It does not provide you with a production ready EKS cluster or setup in general.
> To run a production ready EKS cluster, [please adhere to the best-practices AWS has defined](https://aws.github.io/aws-eks-best-practices/).
> In order to make this experience as easy as possible for you, the Kubernetes API of this sample will be reachable from the public internet.
> This is not recommended in production.

---

## 🔢 Pre-requisites

You must have the following tools installed on your system:
  * AWS CLI (version 2.15.0 or later)
    * [Installing AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions)
  * Packer (version 1.10.0 or later)
    * [Installing Packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli)
  * Terraform (version 1.7.0 or later)
    * [Installing Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
  * Kubectl (version 1.29.x)
    * [Installing Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
  * Finch (needed if you want to build the example for WasmEdge)
    * [Installing Finch](https://runfinch.com/docs/getting-started/installation/)
  * Cloning the repo to your environment

The easiest way to authenticate Packer and Terraform is [through setting up authentication in the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html). Please keep in mind that you will need many permissions to setup this environment. It is assumed that the credentials you use have administrator permissions.

To test if your AWS CLI works and you are authenticated, run this command:
```
aws sts get-caller-identity --output json
````

The output should look like this:
```
{
    "UserId": "UUID123123:your_user",
    "Account": "111122223333",
    "Arn": "arn:aws:sts::111122223333:assumed-role/some-role/your_user"
}
```
Take note of your account-id, as you will need it later.

> **Note**
> The default instance type to build the AMI and the EKS cluster does not qualify for the AWS free tier.
> You are charged for any instances created when building this AMI and the EKS cluster.
> An EKS cluster in itself does not qualify for the AWS free tier as well.
> You are charged for any EKS cluster you deploy while building this sample.

## 👷 Building the AMI

You will need to have a default VPC in the region where the AMI will be created, or provide a subnet ID via the subnet_id variable. The remaining variables are optional and can be modified to suit; either through the `al2023_amd64.pkrvars.hcl` file or by passing via -var 'key=value' on the Packer CLI. See the `variables.pkr.hcl` file for variables that are available for customization.

Before running the commands to create the AMI, do this:

1. Set the `region` variable inside the `packer/al2023_amd64.pkrvars.hcl` file

To build the AMI, run the following commands on your CLI from inside the repository:
```
cd packer
packer init -upgrade .
packer build -var-file=al2023_amd64.pkrvars.hcl .
```

The build should take about 10 minutes (depending on the instance you choose).
After finishing, you see output similar to this:
```
==> Builds finished. The artifacts of successful builds are:
--> amazon-eks.amazon-ebs.this: AMIs were created:
your-region: ami-123456789abc
```
Note the AMI-ID somewhere, you are going to need it in the next step.

## Building the EKS cluster
To build the EKS cluster, you must first do the following:

1. Update the `region` inside the `terraform/providers.tf` file to the same region you have set for Packer inside the `packer/al2023_amd64.pkrvars.hcl` file.
2. Set the `custom_ami_id` parameter inside the `terraform/eks.tf` file to the AMI-ID from the output of Packer.

To build the cluster, run the following commands on your CLI from inside the repository (you must confirm the last command):
```
cd terraform
terraform init
terraform plan
terraform apply
```

The output of `terraform apply` tells you what Terraform is currently creating. You can use the AWS console (WebUI) to check the progress for individual items.
The process should take 15-20 minutes to complete on average.

## Running an example workload with the Spin runtime
When your cluster has finished creating, run the following command to configure kubectl for access to your cluster:
```
aws eks update-kubeconfig --name webassembly-on-eks --region <UPDATE_REGION>
```

After that, run the following commands to first create RuntimeClasses for both Spin and WasmEdge and then an example workload that uses Spin as the runtime:
```
kubectl apply -f kubernetes/runtimeclass.yaml
kubectl apply -f kubernetes/deployment-spin.yaml
```

Check if the pod has started successfully (this may take a few seconds the first time you run it):
```
kubectl get pods -n default
```

Now let's see if it works:
```
kubectl port-forward service/hello-spin 8080:80
```
If you now access `http://localhost:8080/hello` in a browser, you should be seeing a message saying "Hello world from Spin!".

This means the Spin runtime is working inside your cluster!

## Building your own image and running it with the WasmEdge runtime

For the next example, you are going to build your own image using Finch and then run it in a deployment.
Before you do this, update the image parameter with your account-id and region in the `kubernetes/deployment-wasmedge.yaml`file.
After that, build and run the image:
```
cd build
export AWS_ACCOUNT_ID=<UPDATE_ACCOUNT_ID>
export AWS_REGION=<UPDATE_REGION>
finch build --tag wasm-example --platform wasi/wasm .
# Get your image ID using this command
finch image ls
finch tag <UPDATE_IMAGE_ID> $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/wasm-example:latest
aws ecr get-login-password --region $AWS_REGION | finch login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
finch push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/wasm-example:latest
kubectl apply -f ../kubernetes/deployment-wasmedge.yaml
```

Check if the pod has started successfully (this may take a few seconds the first time you run it):
```
kubectl get pods -n default
```

Now let's see if it works:
```
kubectl port-forward service/wasmedge-hello 8081:80
```

If you now access `http://localhost:8081` in a browser, you should be seeing a message saying "Hello world from WasmEdge!".

This means the WasmEdge runtime is working inside your cluster!

Congratulations! You can now run WebAssembly workloads with both the Spin and the WasmEdge runtime on Amazon EKS!

## Cleaning up
To clean up the resources you created, run the following commands from inside the repository (you have to confirm the second command):
```
aws ecr batch-delete-image --region $AWS_REGION --repository-name wasm-example --image-ids "$(aws ecr list-images --region $AWS_REGION --repository-name wasm-example --query 'imageIds[*]' --output json)"
cd terraform
terraform destroy
```

This will take around 15 minutes to complete again.
After that you still have to delete the custom AMI and its snapshots. For this you run these commands:
```
Snapshots="$(aws ec2 describe-images --image-ids <UPDATE_AMI_ID> --region <UPDATE_REGION> --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId' --output text)"

aws ec2 deregister-image --image-id <UPDATE_AMI_ID> --region <UPDATE_REGION>

for SNAPSHOT in $Snapshots ; do aws ec2 delete-snapshot --snapshot-id $SNAPSHOT; done
```

## 🔒 Security

For security issues or concerns, please do not open an issue or pull request on GitHub. Please report any suspected or confirmed security issues to AWS Security https://aws.amazon.com/security/vulnerability-reporting/

## ⚖️ License Summary

This sample code is made available under a modified MIT license. See the LICENSE file.