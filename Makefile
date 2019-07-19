SHELL=/bin/bash

.PHONY: clean
clean: vault-clean consul-clean helm-clean

.PHONY: k8s
k8s:
	@echo 'Add local-path storage for k3s for PVC support...'
	kubectl apply -f manifests/local-path-storage.yaml

.PHONY: helm helm-clean helm-install
helm: helm-clean helm-install
helm-clean:
	@echo 'Resetting Helm...'
	if helm version > /dev/null 2>&1 ; then helm reset -f; fi

	@echo 'Removing Helm RBAC config...'
	if kubectl get serviceaccount tiller > /dev/null 2>&1 ; then kubectl delete -f helm/tiller/rbac-config.yaml; fi

helm-install:
	@echo 'Setup up Helm RBAC...'
	kubectl apply -f helm/tiller/rbac-config.yaml

	@echo 'Installing Helm...'
	helm init --service-account tiller --history-max 200 --wait
	kubectl -n kube-system get service tiller-deploy
	helm version

.PHONY: consul consul-clean consul-install
consul: consul-clean consul-install
consul-clean:
	@echo 'Removing old Consul deployments...'
	if helm get consul4vault > /dev/null 2>&1 ; then \
		helm delete --purge consul4vault; \
	fi

	@echo 'Removing any lingering Consul PVCs...'
	for i in `kubectl get pvc --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep consul4vault` ; do \
		kubectl delete pvc $$i; \
	done

consul-install:
	@echo 'Fetching Consul Helm Chart...'
	if ! test -d helm/consul/chart/consul-helm ; then \
		mkdir -p helm/consul/chart ;\
		git clone git@github.com:hashicorp/consul-helm helm/consul/chart/consul-helm ; \
	fi
	cd helm/consul/chart/consul-helm && git checkout v0.8.1

	@echo 'Creating Consul cluster for Vault storage...'
	helm install --wait -f helm/consul/values.yaml helm/consul/chart/consul-helm \
		--name consul4vault

.PHONY: vault vault-clean vault-install
vault: vault-clean vault-install
vault-clean:
	@echo 'Removing old Vault deployments...'
	if helm get vault > /dev/null 2>&1 ; then \
		helm delete --purge vault4k8s; \
	fi

	@echo 'Removing any lingering Vault PVCs...'
	for i in `kubectl get pvc --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep vault4k8s` ; do \
		kubectl delete pvc $$i; \
	done

vault-install:
	@echo 'Fetching Vault Helm Chart...'
	if ! test -d helm/vault/chart/vault-helm ; then \
		mkdir -p helm/vault/chart ;\
		git clone git@github.com:hashicorp/vault-helm helm/vault/chart/vault-helm ; \
	fi
	cd helm/vault/chart/vault-helm && git checkout v0.0.1

	@echo 'Creating Vault service ***without helm --wait***...'
	@echo '*** NOTICE: You must init and unseal Vault for the SVC to become "ready"! ***'
	helm install -f helm/vault/values.yaml helm/vault/chart/vault-helm \
		--name vault4k8s
