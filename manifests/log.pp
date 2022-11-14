define cloudwatchlogs::log (
  Optional[Stdlib::Absolutepath] $path       = undef,
  String $streamname                         = '{instance_id}',
  String $datetime_format                    = '%b %d %H:%M:%S',
  Optional[String] $log_group_name           = undef,
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

  concat::fragment { "cloudwatchlogs_fragment_${name}":
    target  => '/etc/awslogs/awslogs.conf',
    content => template('cloudwatchlogs/awslogs_log.erb'),
  }

}
