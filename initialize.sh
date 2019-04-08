#!/usr/bin/env bash

# Create Cluster Role Binding for cluster admin
kubectl create clusterrolebinding "cluster-admin-$(whoami)" --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"

# Install Helm (Client)
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get | bash

# Install Tiller (Helm Server)
kubectl -n kube-system create sa tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --skip-refresh --upgrade --service-account tiller

# Install Flux Client (unsure if done by helm?)
# wget https://github.com/weaveworks/flux/releases/download/1.11.1/fluxctl_linux_amd64
# sudo install -m 755 fluxctl_linux_amd64 /usr/local/bin/fluxctl
# Set flux namespace
# export FLUX_FORWARD_NAMESPACE=flux
# export FLUX_URL=http://127.0.0.1:3030/api/flux

# Install Flux Server
helm repo add weaveworks https://weaveworks.github.io/flux
helm install --name flux --set rbac.create=true --set helmOperator.create=true --set git.url=git@github.com:vanderstack/gitops-helm --namespace flux weaveworks/flux

# Create GitHub Write Access Deploy Key: 
# Use Browser: https://github.com/vanderstack/gitops-helm/settings/keys/new
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

# Create example secret
# kubectl -n dev create secret generic basic-auth --from-literal=user=admin --from-literal=password=admin --dry-run -o json > basic-auth.json
# kubeseal --format=yaml --cert=pub-cert.pem < basic-auth.json > basic-auth.yaml
# rm basic-auth.json
# mv basic-auth.yaml /releases/dev/
# git stage releases/dev/basic-auth.yaml
# git commit -a -m "Add basic auth credentials to dev namespace (example)"
# git push

# Back up Sealed Secrets Private Key
# kubectl get secret -n adm sealed-secrets-key -o yaml --export > sealed-secrets-key.yaml
echo ">>>> This is the Private Key used to decrypt Sealed Secrets <<<<"
echo ">>>> Please make a backup avoid losing access to Sealed Secrets <<<<"
kubectl get secret -n adm sealed-secrets-key -o yaml --export | cat

# Restore Sealed Secrets Private Key
# kubectl replace secret -n adm sealed-secrets-key -f sealed-secrets-key.yaml

# Restart Sealed Secrets Pod
# kubectl delete pod -n adm -l app=sealed-secrets

# Trigger a new build
# cd hack && ./ci-mock.sh -r "podinfo" -b dev

# Force Flux Synchronization (default 5 minute wait)
# fluxctl sync

# Review Flux Logs
# kubectl -n flux logs deployment/flux -f

# View Workloads
# fluxctl list-workloads --all-namespaces

# Inspect Container Version
# fluxctl list-images --workload {workload name}

# Automate Workload
# fluxctl automate --workload={workload name}

# Turn off Automation
# fluxctl automate --workload={workload name}
