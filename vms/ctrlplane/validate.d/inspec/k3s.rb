control 'API port' do
  title 'check for listening k8s API port'
  describe port(6443) do
    it { should be_listening }
    its('protocols') { should include 'tcp' }
  end
end

control 'k3s service' do
  title 'check for running k3s service'
  describe service('k3s') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
end

control 'k3s control plane - tiller service account' do
  title 'service account exists for Helm Tiller'
  describe command('k3s kubectl get serviceaccount tiller -n kube-system') do
    its('exit_status') { should eq 0 }
  end
end

control 'k3s control plane - local-path storage class' do
  title 'local-path storage class exists'
  describe command('k3s kubectl get storageclass local-path') do
    its('exit_status') { should eq 0 }
  end
end
