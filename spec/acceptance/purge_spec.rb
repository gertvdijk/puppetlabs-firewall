require 'spec_helper_acceptance'

describe "purge tests:", :unless => UNSUPPORTED_PLATFORMS.include?(fact('osfamily')) do
  context('resources purge') do
    before(:all) do
      iptables_flush_all_tables

      shell('iptables -A INPUT -s 1.2.1.2')
      shell('iptables -A INPUT -s 1.2.1.2')
    end

    it 'make sure duplicate existing rules get purged' do

      pp = <<-EOS
        class { 'firewall': }
        resources { 'firewall':
          purge => true,
        }
      EOS

      apply_manifest(pp, :expect_changes => true)
    end

    it 'saves' do
      shell('iptables-save') do |r|
        expect(r.stdout).to_not match(/1\.2\.1\.2/)
        expect(r.stderr).to eq("")
      end
    end
  end

  context('ipv4 chain purge') do
    after(:all) do
      iptables_flush_all_tables
    end
    before(:each) do
      iptables_flush_all_tables

      shell('iptables -A INPUT -p tcp -s 1.2.1.1')
      shell('iptables -A INPUT -p udp -s 1.2.1.1')
      shell('iptables -A OUTPUT -s 1.2.1.2 -m comment --comment "010 output-1.2.1.2"')
    end

    it 'purges only the specified chain' do
      pp = <<-EOS
        class { 'firewall': }
        firewallchain { 'INPUT:filter:IPv4':
          purge => true,
        }
      EOS

      apply_manifest(pp, :expect_changes => true)

      shell('iptables-save') do |r|
        expect(r.stdout).to match(/010 output-1\.2\.1\.2/)
        expect(r.stdout).to_not match(/1\.2\.1\.1/)
        expect(r.stderr).to eq("")
      end
    end

    it 'ignores managed rules' do
      pp = <<-EOS
        class { 'firewall': }
        firewallchain { 'OUTPUT:filter:IPv4':
          purge => true,
        }
        firewall { '010 output-1.2.1.2':
          chain  => 'OUTPUT',
          proto  => 'all',
          source => '1.2.1.2',
        }
      EOS

      unless fact('selinux') == 'true'
        apply_manifest(pp, :catch_changes => true)
      end
    end

    it 'ignores specified rules' do
      pp = <<-EOS
        class { 'firewall': }
        firewallchain { 'INPUT:filter:IPv4':
          purge => true,
          ignore => [
            '-s 1\.2\.1\.1',
          ],
        }
      EOS

      if fact('selinux') == 'true'
        apply_manifest(pp, :catch_failures => true)
      else
        apply_manifest(pp, :catch_changes => true)
      end
    end

    it 'adds managed rules with ignored rules' do
      pp = <<-EOS
        class { 'firewall': }
        firewallchain { 'INPUT:filter:IPv4':
          purge => true,
          ignore => [
            '-s 1\.2\.1\.1',
          ],
        }
        firewall { '014 input-1.2.1.6':
          chain  => 'INPUT',
          proto  => 'all',
          source => '1.2.1.6',
        }
        -> firewall { '013 input-1.2.1.5':
          chain  => 'INPUT',
          proto  => 'all',
          source => '1.2.1.5',
        }
        -> firewall { '012 input-1.2.1.4':
          chain  => 'INPUT',
          proto  => 'all',
          source => '1.2.1.4',
        }
        -> firewall { '011 input-1.2.1.3':
          chain  => 'INPUT',
          proto  => 'all',
          source => '1.2.1.3',
        }
      EOS

      apply_manifest(pp, :catch_failures => true)

      expect(shell('iptables-save').stdout).to match(/-A INPUT -s 1\.2\.1\.1(\/32)? -p tcp\s?\n-A INPUT -s 1\.2\.1\.1(\/32)? -p udp/)
    end
  end
  context 'ipv6 chain purge', :unless => (fact('osfamily') == 'RedHat' and fact('operatingsystemmajrelease') == '5') do
    after(:all) do
      ip6tables_flush_all_tables
    end
    before(:each) do
      ip6tables_flush_all_tables

      shell('ip6tables -A INPUT -p tcp -s 1::42')
      shell('ip6tables -A INPUT -p udp -s 1::42')
      shell('ip6tables -A OUTPUT -s 1::50 -m comment --comment "010 output-1::50"')
    end

    it 'purges only the specified chain' do
      pp = <<-EOS
        class { 'firewall': }
        firewallchain { 'INPUT:filter:IPv6':
          purge => true,
        }
      EOS

      apply_manifest(pp, :expect_changes => true)

      shell('ip6tables-save') do |r|
        expect(r.stdout).to match(/010 output-1::50/)
        expect(r.stdout).to_not match(/1::42/)
        expect(r.stderr).to eq("")
      end
    end

    it 'ignores managed rules' do
      pp = <<-EOS
        class { 'firewall': }
        firewallchain { 'OUTPUT:filter:IPv6':
          purge => true,
        }
        firewall { '010 output-1::50':
          chain    => 'OUTPUT',
          proto    => 'all',
          source   => '1::50',
          provider => 'ip6tables',
        }
      EOS

      unless fact('selinux') == 'true'
        apply_manifest(pp, :catch_changes => true)
      end
    end

    it 'ignores specified rules' do
      pp = <<-EOS
        class { 'firewall': }
        firewallchain { 'INPUT:filter:IPv6':
          purge => true,
          ignore => [
            '-s 1::42',
          ],
        }
      EOS

      if fact('selinux') == 'true'
        apply_manifest(pp, :catch_failures => true)
      else
        apply_manifest(pp, :catch_changes => true)
      end
    end

    it 'adds managed rules with ignored rules' do
      pp = <<-EOS
        class { 'firewall': }
        firewallchain { 'INPUT:filter:IPv6':
          purge => true,
          ignore => [
            '-s 1::42',
          ],
        }
        firewall { '014 input-1::46':
          chain    => 'INPUT',
          proto    => 'all',
          source   => '1::46',
          provider => 'ip6tables',
        }
        -> firewall { '013 input-1::45':
          chain    => 'INPUT',
          proto    => 'all',
          source   => '1::45',
          provider => 'ip6tables',
        }
        -> firewall { '012 input-1::44':
          chain    => 'INPUT',
          proto    => 'all',
          source   => '1::44',
          provider => 'ip6tables',
        }
        -> firewall { '011 input-1::43':
          chain    => 'INPUT',
          proto    => 'all',
          source   => '1::43',
          provider => 'ip6tables',
        }
      EOS

      apply_manifest(pp, :catch_failures => true)

      expect(shell('ip6tables-save').stdout).to match(/-A INPUT -s 1::42(\/128)? -p tcp\s?\n-A INPUT -s 1::42(\/128)? -p udp/)
    end
  end
end
