# = Type: static_arp::collector
#
# A simple class to collect all the exported ARP entries. If you need to use
# tags to generate subsets of entries appropriate to a node's networks, you'll
# need to roll your own.
#
# (Perhaps a future puppet version will include an 'in' operator in the
# resource collector search expression syntax.)
#
class static_arp::collector () {
  Static_arp::Entry <<| |>>
}
