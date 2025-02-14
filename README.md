# ROSA CSI Driver Setup Guide

## Table of Contents
1. [Repository Link](#repository-link)
2. [Prerequisites](#prerequisites)
3. [Setup Instructions](#setup-instructions)
   - [Verify STS Configuration](#verify-sts-configuration)
   - [Set SCCs to Allow CSI Driver](#set-sccs-to-allow-csi-driver)
   - [Create Environment Variables](#create-environment-variables)
   - [Verify OIDC Provider](#verify-oidc-provider)
   - [Deploy AWS Secrets and Configuration Provider](#deploy-aws-secrets-and-configuration-provider)
   - [Install and Configure Helm](#install-and-configure-helm)
   - [Install Secrets Store CSI Driver](#install-secrets-store-csi-driver)
   - [Deploy AWS Provider](#deploy-aws-provider)
   - [Verify Daemon Sets](#verify-daemon-sets)
   - [Label Secrets Store CSI Driver](#label-secrets-store-csi-driver)
4. [Create AWS Secret and IAM Access Policies](#create-aws-secret-and-iam-access-policies)
5. [Create OpenShift Resources](#create-openshift-resources)
   - [Create OpenShift Project](#create-openshift-project)
   - [Create Service Account](#create-service-account)
   - [Annotate Service Account](#annotate-service-account)
6. [Create and Mount Secrets](#create-and-mount-secrets)
   - [Create Secret Provider Class](#create-secret-provider-class)
   - [Deploy an Application Pod](#deploy-an-application-pod)
   - [Verify Secret Mount](#verify-secret-mount)
   - [Expose Secret as Environment Variable](#expose-secret-as-environment-variable)

---

## Repository Link
[GitHub Repository](<insert-repo-link-here>)

## Prerequisites
Before starting, ensure the following requirements are met:
- AWS CLI installed and configured
- OpenShift ROSA cluster
- Helm installed
- IAM permissions to create policies and roles
- Access to AWS Secrets Manager
- OpenShift CLI (`oc`) installed

## Setup Instructions

### Verify STS Configuration
```sh
rosa list oidc-providers
```
Ensure the STS provider exists and is correctly configured.

### Set SCCs to Allow CSI Driver
```sh
oc adm policy add-scc-to-user privileged -z <service-account>
```

### Create Environment Variables
```sh
export CLUSTER_NAME="your-cluster"
export AWS_REGION="your-region"
```

### Verify OIDC Provider
```sh
aws iam list-open-id-connect-providers | grep <OIDC_ENDPOINT>
```
Ensure the OIDC provider matches the OpenShift cluster’s endpoint.

### Deploy AWS Secrets and Configuration Provider
```sh
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
```

### Install and Configure Helm
```sh
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update
```

### Install Secrets Store CSI Driver
```sh
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system
```

### Deploy AWS Provider
```sh
kubectl apply -f aws-provider.yaml
```

### Verify Daemon Sets
```sh
kubectl get daemonset -n kube-system
```
Ensure both the CSI driver and AWS provider daemon sets are running.

### Label Secrets Store CSI Driver
```sh
oc label ns kube-system pod-security.kubernetes.io/enforce=restricted
```

### Verify Label
```sh
kubectl get ns kube-system --show-labels
```

## Create AWS Secret and IAM Access Policies

### Create a Secret in AWS Secrets Manager
```sh
aws secretsmanager create-secret --name mySecret --secret-string "{"password":"mypassword"}"
```

### Create IAM Access Policy Document
```sh
cat <<EOF > secret-access-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:<AWS_REGION>:<ACCOUNT_ID>:secret:mySecret"
    }
  ]
}
EOF
```

### Create IAM Role Trust Policy Document
```sh
cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/<OIDC_ENDPOINT>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity"
    }
  ]
}
EOF
```

### Create IAM Role and Attach Policy
```sh
aws iam create-role --role-name my-secret-role --assume-role-policy-document file://trust-policy.json
aws iam put-role-policy --role-name my-secret-role --policy-name SecretAccessPolicy --policy-document file://secret-access-policy.json
```

### Verify Role and Policy Attachment
```sh
aws iam get-role --role-name my-secret-role
aws iam list-role-policies --role-name my-secret-role
```

## Create OpenShift Resources

### Create OpenShift Project
```sh
oc new-project secret-demo
```

### Create Service Account
```sh
oc create serviceaccount secret-sa
```

### Annotate Service Account for STS Role
```sh
oc annotate serviceaccount secret-sa eks.amazonaws.com/role-arn=arn:aws:iam::<ACCOUNT_ID>:role/my-secret-role
```

### Verify Annotation
```sh
oc get serviceaccount secret-sa -o yaml
```

## Create and Mount Secrets

### Create Secret Provider Class
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: aws-secrets
  namespace: secret-demo
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "mySecret"
        objectType: "secretsmanager"
```

### Deploy an Application Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-test-pod
  namespace: secret-demo
spec:
  serviceAccountName: secret-sa
  containers:
    - name: busybox
      image: busybox
      command: ["sleep", "3600"]
      volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets-store"
          readOnly: true
  volumes:
    - name: secrets-store
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "aws-secrets"
```

### Verify Secret Mount
```sh
kubectl exec -it secret-test-pod -- ls /mnt/secrets-store
```

### Expose Secret as Environment Variable
```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: mySecret
        key: password
```

## Conclusion
This guide provides a step-by-step approach to configuring the ROSA CSI driver with AWS Secrets Manager. Ensure each step is followed correctly to securely manage secrets in OpenShift ROSA.


