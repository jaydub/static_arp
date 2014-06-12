# Creates a file fragment via concat which contains an IP to MAC
# address mapping.

define static_arp::entry ($ip, $mac) {
  validate_string($ip)
  if $ip == '' or $ip == undef {
    fail('Emtpy IP value supplied to static_arp::entry.')
  }
  validate_string($mac)
  if $mac == '' or $mac == undef {
    fail('Emtpy MAC value supplied to static_arp::entry.')
  }
  concat::fragment { "${title}_static_arp_fragment":
    target  => 'ethers',
    content => "${ip} ${mac}\n",
  }
}
