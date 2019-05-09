control 'ks3 agent' do
  title 'check for running k3s agent'
  describe service('k3s-agent') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
end
