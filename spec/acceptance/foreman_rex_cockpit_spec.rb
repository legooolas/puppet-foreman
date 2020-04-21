require 'spec_helper_acceptance'

describe 'Scenario: install foreman', if: os[:family] == 'centos' do
  apache_service_name = ['debian', 'ubuntu'].include?(os[:family]) ? 'apache2' : 'httpd'

  before(:context) do
    case fact('osfamily')
    when 'RedHat'
      on default, 'yum -y remove foreman* tfm-*'
    when 'Debian'
      on default, 'apt-get purge -y foreman*', { :acceptable_exit_codes => [0, 100] }
      on default, 'apt-get purge -y ruby-hammer-cli-*', { :acceptable_exit_codes => [0, 100] }
    end

    on default, "systemctl stop #{apache_service_name}", { :acceptable_exit_codes => [0, 5] }
  end

  let(:pp) do
    <<-EOS
    if $facts['os']['family'] == 'RedHat' and $facts['os']['name'] != 'Fedora' {
      class { 'redis::globals':
        scl => 'rh-redis5',
      }
    }

    $directory = '/etc/foreman-certs'
    $certificate = "${directory}/certificate.pem"
    $key = "${directory}/key.pem"

    class { 'foreman':
      user_groups            => [],
      initial_admin_username => 'admin',
      initial_admin_password => 'changeme',
      server_ssl_ca          => $certificate,
      server_ssl_chain       => $certificate,
      server_ssl_cert        => $certificate,
      server_ssl_key         => $key,
      server_ssl_crl         => '',
    }
    include foreman::plugin::remote_execution::cockpit
    EOS
  end

  it_behaves_like 'a idempotent resource'

  it_behaves_like 'the foreman application'

  describe port(19090) do
    it { is_expected.to be_listening.on('127.0.0.1').with('tcp') }
  end
end
