# == Class: cloudwatchlogs
#
# Configure AWS Cloudwatch Logs on Amazon Linux instances.
#
# === Variables
#
# [*state_file*]
#   State file for the awslogs agent.
#
# [*region*]
#   The region your EC2 instance is running in.
#
# === Examples
#
#  include '::cloudwatchlogs'
#
#  class { '::cloudwatchlogs': region => 'eu-west-1' }
#
# === Authors
#
# Danny Roberts <danny.roberts@reconnix.com>
# Russ McKendrick <russ.mckendrick@reconnix.com>
#
# === Copyright
#
# Copyright 2015 Danny Roberts & Russ McKendrick
#
class cloudwatchlogs (
  Stdlib::Absolutepath $state_file          = $::cloudwatchlogs::params::state_file,
  Stdlib::Absolutepath $logging_config_file = $::cloudwatchlogs::params::logging_config_file,
  Optional[String] $region                  = $::cloudwatchlogs::params::region,
  Optional[String] $log_level               = $::cloudwatchlogs::params::log_level,
  Hash $logs                                = {}
) inherits cloudwatchlogs::params {

  $logs_real = merge(lookup('cloudwatchlogs::logs', undef, undef, {}), $logs)

  $installed_marker = $facts['os']['name'] ? {
    'Amazon'    => Package['awslogs'],
    'AlmaLinux' => Package['amazon-cloudwatch-agent'],
    default     => Exec['cloudwatchlogs-install'],
  }

  create_resources('cloudwatchlogs::log', $logs_real)

  case $facts['os']['name'] {
    'Amazon': {
      package { 'awslogs':
        ensure => 'present',
      }

      concat { '/etc/awslogs/awslogs.conf':
        ensure         => 'present',
        owner          => 'root',
        group          => 'root',
        mode           => '0644',
        ensure_newline => true,
        warn           => true,
        require        => Package['awslogs'],
      }
      concat::fragment { 'awslogs-header':
        target  => '/etc/awslogs/awslogs.conf',
        content => template('cloudwatchlogs/awslogs_header.erb'),
        order   => '00',
      }

      if $region {
        file_line { 'region-on-awslogs':
          path    => '/etc/awslogs/awscli.conf',
          line    => "region = ${region}",
          match   => '^region\s*=',
          notify  => Service[$cloudwatchlogs::params::service_name],
          require => Package['awslogs'],
        }
      }

      service { $cloudwatchlogs::params::service_name:
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        subscribe  => Concat['/etc/awslogs/awslogs.conf'],
      }
    }
    /^(AlmaLinux)$/: {
      if !defined(Package['wget']) {
        package { 'wget':
          ensure => 'present',
        }
      }

      exec { 'cloudwatchlogs-wget-rpm':
        path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
        command => 'wget -O /usr/local/src/amazon-cloudwatch-agent.rpm https://amazoncloudwatch-agent.s3.amazonaws.com/redhat/amd64/latest/amazon-cloudwatch-agent.rpm',
        unless  => '[ -e /usr/local/src/amazon-cloudwatch-agent.rpm ]',
        require => Package['wget'],
      }

      package { 'amazon-cloudwatch-agent':
        ensure   => 'present',
        provider => 'dnf',
        source   => '/usr/local/src/amazon-cloudwatch-agent.rpm',
        require  => Exec['cloudwatchlogs-wget-rpm'],
      }

      file { ['/etc/awslogs', '/etc/awslogs/config']:
        ensure  => 'directory',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['amazon-cloudwatch-agent'],
      }

      concat { '/etc/awslogs/awslogs.conf':
        ensure         => 'present',
        owner          => 'root',
        group          => 'root',
        mode           => '0644',
        ensure_newline => true,
        warn           => true,
        require        => File['/etc/awslogs'],
      }
      concat::fragment { 'awslogs-header':
        target  => '/etc/awslogs/awslogs.conf',
        content => template('cloudwatchlogs/awslogs_header.erb'),
        order   => '00',
      }

      service { $cloudwatchlogs::params::service_name:
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        subscribe  => Concat['/etc/awslogs/awslogs.conf'],
      }
    }
    /^(Ubuntu|CentOS|RedHat)$/: {
      if !defined(Package['wget']) {
        package { 'wget':
          ensure => 'present',
        }
      }

      exec { 'cloudwatchlogs-wget':
        path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
        command => 'wget -O /usr/local/src/awslogs-agent-setup.py https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py',
        unless  => '[ -e /usr/local/src/awslogs-agent-setup.py ]',
        require => Package['wget'],
      }

      file { '/etc/awslogs':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }
      -> concat { '/etc/awslogs/awslogs.conf':
        ensure         => 'present',
        owner          => 'root',
        group          => 'root',
        mode           => '0644',
        ensure_newline => true,
        warn           => true,
      }
      -> file { '/etc/awslogs/config':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }

      concat::fragment { 'awslogs-header':
        target  => '/etc/awslogs/awslogs.conf',
        content => template('cloudwatchlogs/awslogs_header.erb'),
        order   => '00',
      }

      file { '/var/awslogs':
        ensure => 'directory',
      }
      -> file { '/var/awslogs/etc':
        ensure => 'directory',
      }
      -> file { '/var/awslogs/etc/awslogs.conf':
        ensure => 'link',
        target => '/etc/awslogs/awslogs.conf',
      }
      -> file { '/var/awslogs/etc/config':
        ensure => 'link',
        force  => true,
        target => '/etc/awslogs/config',
      }

      if ($region == undef) {
        fail("region must be defined on ${facts['os']['name']}")
      } else {
        exec { 'cloudwatchlogs-install':
          path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
          command => "python3 /usr/local/src/awslogs-agent-setup.py -n -r ${region} -c /etc/awslogs/awslogs.conf",
          onlyif  => '[ -e /usr/local/src/awslogs-agent-setup.py ]',
          unless  => '[ -d /var/awslogs/bin ]',
          require => [
            Concat['/etc/awslogs/awslogs.conf'],
            Exec['cloudwatchlogs-wget']
          ],
          before  => [
            Service[$cloudwatchlogs::params::service_name],
            File['/var/awslogs/etc/awslogs.conf'],
          ]
        }
      }

      service { $cloudwatchlogs::params::service_name:
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        subscribe  => Concat['/etc/awslogs/awslogs.conf'],
        require    => File['/var/awslogs/etc/awslogs.conf'],
      }
    }
    default: { fail("The ${module_name} module is not supported on ${facts['os']['family']}/${facts['os']['name']}.") }
  }

  if $log_level {
    file { '/etc/awslogs/awslogs_dot_log.conf':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('cloudwatchlogs/awslogs_logging_config_file.erb'),
      notify  => Service[$cloudwatchlogs::params::service_name],
      require => $installed_marker,
    }
  }
}
