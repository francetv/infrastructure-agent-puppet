# Configure package repository
#
class newrelic_infra::repo (
  $ensure               = 'latest',
  $package_repo_ensure  = 'present',
  $windows_provider     = 'windows',
  $windows_temp_folder  = 'C:/users/Administrator/Downloads',
  $linux_provider       = 'package_manager',
){

  case $facts['kernel'] {
    'Linux': {
      case $linux_provider {
        'package_manager': {
          # Setup agent package repo
          case $facts['os']['name'] {
            'Debian', 'Ubuntu': {
              ensure_packages('apt-transport-https')
              apt::source { 'newrelic_infra-agent':
                ensure       => $package_repo_ensure,
                location     => 'https://download.newrelic.com/infrastructure_agent/linux/apt',
                release      => $::lsbdistcodename,
                repos        => 'main',
                architecture => 'amd64',
                key          => {
                  'id'     => 'A758B3FBCD43BE8D123A3476BB29EE038ECCE87C',
                  'source' => 'https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg',
                },
                require      => Package['apt-transport-https'],
              }
              # work around necessary to get Puppet and Apt to get along on first run, per ticket open as of this writing
              # https://tickets.puppetlabs.com/browse/MODULES-2190?focusedCommentId=341801&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-341801
              exec { 'newrelic_infra_apt_get_update':
                command     => 'apt-get update',
                cwd         => '/tmp',
                path        => ['/usr/bin'],
                subscribe   => Apt::Source['newrelic_infra-agent'],
                refreshonly => true,
              }
            }
            'RedHat', 'CentOS', 'Amazon', 'OracleLinux': {
              if ($::operatingsystem == 'Amazon') {
                $repo_releasever = '6'
              } else {
                $repo_releasever = $::operatingsystemmajrelease
              }
              yumrepo { 'newrelic_infra-agent':
                ensure        => $package_repo_ensure,
                descr         => 'New Relic Infrastructure',
                baseurl       => "https://download.newrelic.com/infrastructure_agent/linux/yum/el/${repo_releasever}/x86_64",
                gpgkey        => 'https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg',
                gpgcheck      => true,
                repo_gpgcheck => $repo_releasever != '5',
              }
            }
            'OpenSuSE', 'SuSE', 'SLED', 'SLES': {
              # work around necessary because sles has a very old version of puppet and zypprepo can't not be installed
              exec { 'download_newrelic_gpg_key':
                command => '/usr/bin/wget https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg -O /opt/newrelic_infra.gpg',
                creates => '/opt/newrelic_infra.gpg',
              }
              ~> exec { 'import_newrelic_gpg_key':
                command     => '/bin/rpm --import /opt/newrelic_infra.gpg',
                refreshonly => true
              }
              -> exec { 'add_newrelic_repo':
                creates => '/etc/zypp/repos.d/newrelic-infra.repo',
                command => "/usr/bin/zypper addrepo --repo http://download.newrelic.com/infrastructure_agent/linux/zypp/sles/${::operatingsystemrelease}/x86_64/newrelic-infra.repo",
                path    => ['/usr/local/sbin', '/usr/local/bin', '/sbin', '/bin', '/usr/bin'],
              }
              # work around necessary because pacakge doesn't have Zypp provider in the puppet SLES version
            }
            default: {
              fail('New Relic Infrastructure agent is not yet supported on this platform')
            }
          }
          Package['newrelic-infra'] -> Service['newrelic-infra']
        }
        default: {
          fail('New Relic Infrastructure agent is not yet supported on this platform')
        }
      }
    }
    default: {
      fail('New Relic Infrastructure agent is not yet supported on this platform')
    }
  }
}
