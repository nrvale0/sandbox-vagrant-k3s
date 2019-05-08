describe port(6443) do
  it { should be_listening }
  its('protocols') { should include 'tcp' }
end

describe service('k3s-service') do
  it { should be_installed }
  it { should be_enabled }
  it { should be_running }
end
