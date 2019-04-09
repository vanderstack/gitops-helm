#!/usr/bin/env bash

# Create Cluster Role Binding for cluster admin
kubectl create clusterrolebinding "cluster-admin-$(whoami)" --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"

# Install Helm (Client)
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash

# Install Tiller (Helm Server)
kubectl -n kube-system create sa tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --skip-refresh --upgrade --service-account tiller

# Set flux namespace
export FLUX_FORWARD_NAMESPACE=flux

# Install Flux Client
wget https://github.com/weaveworks/flux/releases/download/1.11.1/fluxctl_linux_amd64
sudo install -m 755 fluxctl_linux_amd64 /usr/local/bin/fluxctl

# Install Flux Server
helm repo add weaveworks https://weaveworks.github.io/flux
helm install --name flux --set rbac.create=true --set helmOperator.create=true --set git.url=git@github.com:vanderstack/gitops-helm --namespace flux weaveworks/flux

# Create GitHub Write Access Deploy Key: 
# Use Browser: https://github.com/vanderstack/gitops-helm/settings/keys/new
echo ">>>> This is the Github Write Access Deploy Key <<<<"
echo ">>>> Please update via browser: https://github.com/vanderstack/gitops-helm/settings/keys/new <<<<"
kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2

# Install Sealed Secretes Client
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.5.1/kubeseal-linux-amd64
sudo install -m 755 kubeseal-linux-amd64 /usr/local/bin/kubeseal

# Clone the git-ops repository for our cluster
git clone https://github.com/vanderstack/gitops-helm.git
cd gitops-helm
git config --global user.email "github@vanderstack.com"
git config --global user.name "VanderStack"

# Add Sealed Secrets public encryption key into repository.
kubeseal --fetch-cert --controller-namespace=adm --controller-name=sealed-secrets > pub-cert.pem
git stage pub-cert.pem
git commit -a -m "Add Sealed Secrets public encryption key"
git push

# Back up Sealed Secrets Private Key
# kubectl get secret -n adm sealed-secrets-key -o yaml --export > sealed-secrets-key.yaml
echo ">>>> This is the Private Key used to decrypt Sealed Secrets <<<<"
echo ">>>> Please make a backup avoid losing access to Sealed Secrets <<<<"
kubectl get secret -n adm sealed-secrets-key -o yaml --export | cat

# Create example secret
# kubectl -n dev create secret generic basic-auth --from-literal=user=admin --from-literal=password=admin --dry-run -o json > basic-auth.json
# kubeseal --format=yaml --cert=pub-cert.pem < basic-auth.json > basic-auth.yaml
# rm basic-auth.json
# mv basic-auth.yaml /releases/dev/
# git stage releases/dev/basic-auth.yaml
# git commit -a -m "Add basic auth credentials to dev namespace (example)"
# git push

# Restore Sealed Secrets Private Key
# kubectl replace secret -n adm sealed-secrets-key -f sealed-secrets-key.yaml

# Restart Sealed Secrets Pod
# kubectl delete pod -n adm -l app=sealed-secrets

# Trigger a new build
# cd hack && ./ci-mock.sh -r "podinfo" -b dev

# List all Pods
# kubectl get pods --all-namespaces -o wide

# Open Shell to pod
# kubectl exec -it {pod name} -- /bin/bash
# kubectl exec -it {pod name} -- /bin/sh

# Force Flux Synchronization (default 5 minute wait)
# kubectl -n flux port-forward deployment/flux-helm-operator 3030:3030 & curl -XPOST http://localhost:3030/api/v1/sync-git
# OR
# fluxctl sync

# Review Flux Logs
# kubectl -n flux logs deployment/flux -f

# View Workloads
# fluxctl list-workloads --all-namespaces

# Inspect Container Version
# fluxctl list-images --controller={workload name}

# Automate Workload
# fluxctl automate --controller={workload name}

# Turn off Automation
# fluxctl automate --controller={workload name}

# Review Helm Release History
# helm history {release name}
# helm history podinfo-dev

# List all Docker Images
# gcloud container images list

# List all tags for a Docker Image
# gcloud container images list-tags gcr.io/vanderstack-1531176539095/podinfo

# Simulate CI Pipeline
## Verify Helm Revision
# helm history podinfo-dev
## Verify Flux Image
# fluxctl list-images --controller=dev:deployment/podinfo-dev
## Invoke Fake CI
# ./ci-mock.sh -r "podinfo" -b dev
## Force Flux Synchronization (default schedule 5 minutes)
# fluxctl sync
## Observe Updated Helm Revision
# helm history podinfo-dev
## Verify Updated Flux Image
# fluxctl list-images --controller=dev:deployment/podinfo-dev
