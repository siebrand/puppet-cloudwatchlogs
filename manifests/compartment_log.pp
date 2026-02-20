# @summary Creates individual log config files in /etc/awslogs/config/
#
# @param path
#   Absolute path to the log file being managed
# @param streamname
#   The name of the stream in Cloudwatch Logs
# @param datetime_format
#   Specifies how the timestamp is extracted from logs
# @param log_group_name
#   Specifies the destination log group
# @param multi_line_start_pattern
#   Regex string that identifies the start of a log line
define cloudwatchlogs::compartment_log (
  Optional[Stdlib::Absolutepath] $path       = undef,
  String $streamname                         = '{instance_id}',
  String $datetime_format                    = '%b %d %H:%M:%S',
  String $log_group_name                     = undef,
  Optional[String] $multi_line_start_pattern = undef,

) {
  if $path == undef {
    $log_path = $name
  } else {
    $log_path = $path
  }
  if $log_group_name == undef {
    $real_log_group_name = $name
  } else {
    $real_log_group_name = $log_group_name
  }

  $installed_marker = $facts['os']['name'] ? {
    'Amazon'    => Package['awslogs'],
    'AlmaLinux' => Package['amazon-cloudwatch-agent'],
    default     => Exec['cloudwatchlogs-install'],
  }

  case $facts['os']['name'] {
    'AlmaLinux': {
      file { "/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/${name}.json":
        ensure  => 'present',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('cloudwatchlogs/cloudwatch_agent_log.json.erb'),
        require => $installed_marker,
        notify  => Service[$::cloudwatchlogs::params::service_name],
      }
    }
    default: {
      concat { "/etc/awslogs/config/${name}.conf":
        ensure         => 'present',
        owner          => 'root',
        group          => 'root',
        mode           => '0644',
        ensure_newline => true,
        warn           => true,
        require        => $installed_marker,
        notify         => Service[$::cloudwatchlogs::params::service_name],
      }
      concat::fragment { "cloudwatchlogs_fragment_${name}":
        target  => "/etc/awslogs/config/${name}.conf",
        content => template('cloudwatchlogs/awslogs_log.erb'),
      }
    }
  }
}
