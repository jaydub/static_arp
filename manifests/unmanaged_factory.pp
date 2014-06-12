# = Type: static_arp::unmanaged_factory
#
# A factory class that pulls data from the unmanaged_static_arp_entries key in
# hiera, and  uses it to create a set of exported static_arp::entry resources,
# for later collection (by static_arp::collector, or other means).
#
class static_arp::unmanaged_factory
(
  $hiera_key = 'unmanaged_static_arp_entries',
  $resource_type = 'static_arp::entry',
  $resource_creation = 'export'
)
{
  case $resource_creation {
    'export':  {create_resources("@@${resource_type}", hiera($hiera_key, {}))}
    'virtual': {create_resources("@${resource_type}", hiera($hiera_key, {}))}
    default:   {create_resources($resource_type, hiera($hiera_key, {}))}
  }
}
