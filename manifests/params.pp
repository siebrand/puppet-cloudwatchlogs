# @summary Default parameters for cloudwatchlogs module
# @api private
class cloudwatchlogs::params {

  case $facts['os']['name'] {
    'Amazon': { $state_file = '/var/lib/awslogs/agent-state' }
    default: { $state_file = '/var/awslogs/state/agent-state' }
  }
  $osname = $facts['os']['name']
  $osmajor = $facts['os']['release']['major']
  $oslong = "${osname}${osmajor}"
  
  case $oslong {
    'Amazon2': { $service_name = 'awslogsd' }
    'AlmaLinux9': { $service_name = 'amazon-cloudwatch-agent' }
    default: { $service_name = 'awslogs' }
  }
  $logging_config_file = '/etc/awslogs/awslogs_dot_log.conf'
  $region = undef
  $log_level = undef
}
