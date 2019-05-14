# control 'IPv6 enabled?' do
#   title 'disable IPv6 to keep k8s networking simple'

#   describe kernel_parameter('net.ipv6.conf.all.disable_ipv6') do
#     its('value') { should eq 1 }
#   end

#   describe kernel_parameter('net.ipv6.conf.default.disable_ipv6') do
#     its('value') { should eq 1 }
#   end

# end
