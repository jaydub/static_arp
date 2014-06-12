# = Class: static_arp
#
# Installs scripts to enable static ARP table entries (also called
# neighbours in the iproute2 and IPv6 lingo) to be installed on
# the target node, from a IP to MAC address mapping stored in /etc/ethers by
# default. Using static ARP entries mitigates the risk of MitM attacks that
# use ARP cache posioning.
#
# The current implementation depends on the net-tools and iproute2 packages,
# making it Debian and derivitive specific, and a Upstart task to handle the
# table loading, making it quite Ubuntu specific (though it should work on
# Ubuntu lucid or later, perhaps even earlier).
#
# == Usage:
#
# On a per node basis, probably inherited in some common section:
#
# class static_arp {}
# @@static_arp::entry { $::clientcert:
#   ip  => $::ipaddress;
#   mac => $::macaddress;
# }
# Static_arp::Entry <<| |>>
#
# I set the configuration of my node's network interfaces through puppet,
# so I tend to get specific about my interfaces in the entry:
#
# @@static_arp::entry { "${::clientcert}_eth0":
#   ip  => $::ipaddress_eth0;
#   mac => $::macaddress_eth0;
# }
#
# Given that I know what the IP is for that interface, because I just assigned
# it, I tend to specify it rather than rely on pulling it from facter.
# Similarly, I note the MAC when bootstraping nodes with puppet client, so I
# tend to write it in by hand.
#
# Of course, as you want *all* your network gizmos in your ARP table, not just
# your managed nodes, so you'll need to add exported entries to some node for
# all of those. At which point, it's really time to pull this data out of hiera.
#
# For your standard nodes:
#
# classes:
#     - static_arp
#     - static_arp::factory
#     - static_arp::collector
#
# And on the node handling the unmanaged entries, include:
#
#     - static_arp::unmanaged_factory
#
# On your regular nodes, specify your arp entries like so:
#
# static_arp_entries:
#     "%{::clientcert}_eth0":
#         ip:  %{::ipaddress_eth0}
#         mac: %{::macaddress_eth0}
#     "%{::clientcert}_eth0_1":
#         ip:  %{::ipaddress_eth0_1}
#         mac: %{::macaddress_eth0_1}
#
#
# In your common.yaml (or elsewhere; I use a specific file at the top of
# my hierachy for this sort of data):
#
# unmanaged_arp_entries:
#     some_gizmo:
#         ip:  SOME_IP
#         mac: THE_MAC
#     (etc)
#
# And now all your local configuration is in hiera where it belongs, leaving
# you to drink the ouzo martini of victory.
#
# === Handling subnets 
#
# In an ideal world we could automatically include attributes describing the
# subnet an entry is part of, and use collector search expressions to build
# an arp table with only the entires appropriate for that node's network
# membership. Unfortunately, the network information that facter produces
# isn't well structured for this sort of thing, and we lack parser level
# loops in the standard parser, besides.
#
# The best available method is to use explicit network assignment for entries
# via tags, and then to use specialised collector classes for each of your
# subnet sets.
#
# == Implementation Notes:
#
# net-tools arp is idempotent, will trump existing MAC entries with
# new ones, and will apply later entries over earlier ones in the
# ethers file. While it will complain about setting an ARP table entry for
# it's  own MAC, it will still process the whole file and return 0; it will
# also do so in cases where entries are garbage.
#
# It almost certainly doesn't add all entries in an atomic fashion, so
# the ideal way to add entries is either:
# * Before network interfaces are bought up
# * By overwriting entries once networking is active
#
# This makes the current flush-and-add strategy used in the current Upstart
# task vulnerable to cache poisoning, but in practice, only briefly. As
# Windows, Mac and *BSD all implement a fairly similarly behaved 'arp'
# command line utility, in future I'll switch to a delete entries missing
# from our file, then add all entries in the file strategy (just as soon as
# I learn me some Ruby).
#
# == Issues:
#
# * The tools support hardware types other than ethernet, but this module
# doesn't, mainly because the file loading option doesn't allow specifying the
# hardware type.
# * We can use hostnames rather than IPs, but don't. This is desirable, as the
# arp table should be populated before the network is up and DNS is available,
# and DNS is probably not to be trusted anymore than ARP. However, I always
# a local hosts file from the same underlying data used to generate the ARP
# table, so it's still feasible. For now, the module is not as flexibe as the
# underlying tools.
# * The Upstart task isn't a long running process, but it's ensure options are
# 'running', which means it gets a kick every puppet run regardless of changes,
# or it's 'stopped', which has what start up and refresh implications?
# * What happens to the static arp table on resumption from suspend and
# hibernate states?
# * The arp tool has a good moan about adding the MAC of one of the local
# network interfaces to the table. Where does that get logged? Guess I should
# read the Upstart docs.

class static_arp ($ethers_path = '/etc/ethers') {
  # Contains the 'arp' tool under Ubuntu and Debian systems
  package { 'net-tools':
    ensure => present,
  }    
  package { 'iproute':
    ensure => present,
  }
  # Installs an Upstart init configuration.
  file { '/etc/init/arp-loader.conf':
    ensure   => file,
    owner    => root,
    group    => root,
    mode     => '0644',
    content  => template('static_arp/arp-loader.conf.erb'),
    notify   => Service['arp-loader'],
  }
  # Base file for our static entries, each added by concat::fragement
  # resources
  concat { 'ethers':
    path   => $ethers_path,
    mode   => '0644',
  }
  # arp-loader is a task, rather than a long running service, but
  # we need it running?
  service { 'arp-loader':
    ensure    => running,
    name      => 'arp-loader',
    provider  => 'upstart',
    require   => File['/etc/init/arp-loader.conf'],
  }
  Package['net-tools'] ->
  Package['iproute'] ->
  File['/etc/init/arp-loader.conf'] ->
  Concat['ethers'] ~>
  Service['arp-loader']
}
