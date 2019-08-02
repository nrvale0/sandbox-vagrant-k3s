SHELL=/bin/bash

.PHONY: clean
clean: vault-clean consul-clean helm-clean

.PHONY: k8s
k8s:
	@echo 'Add local-path storage for k3s for PVC support...'
	kubectl apply -f manifests/local-path-storage.yaml

	@echo 'Labeling worker nodes with failure domains and node labels...'
	for i in az0 az1 az2; do \
		for j in `kubectl get nodes --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | grep $$i`; do \
		kubectl label --overwrite nodes $$j failure-domain.beta.kubernetes.io/zone=$$i; \
		kubectl label --overwrite nodes $$j dedicated_to=vault4k8s; \
		done \
	done
	kubectl get nodes --show-labels

	@echo 'Tainting workers nodes 0 through 2 in each AZ...'
	for i in `kubectl get nodes --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' | egrep -v kubelet3`; do \
		kubectl taint --overwrite=true nodes $$i taint_for_consul_xor_vault=true:NoExecute; \
	done
	kubectl get nodes --template '{{range.items}}{{.metadata.name}} {{.spec.taints}}{{"\n"}}{{end}}'

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
	cd helm/vault/chart/vault-helm && \
	git branch -t stanzas origin/stanzas && \
	git checkout stanzas

	@echo 'Creating Vault service ***without helm --wait***...'
	@echo '*** NOTICE: You must init and unseal Vault for the SVC to become "ready"! ***'
	helm install -f helm/vault/values.yaml helm/vault/chart/vault-helm \
		--name vault4k8s
