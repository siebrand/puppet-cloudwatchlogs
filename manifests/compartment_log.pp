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

  $installed_marker = $::operatingsystem ? {
    'Amazon' => Package['awslogs'],
    default  => Exec['cloudwatchlogs-install'],
  }

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
