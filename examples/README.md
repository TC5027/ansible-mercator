# Examples

First consider the ```inventory/``` folder:

It represents a fleet of servers grouped as [CEPH](https://ceph.io/en/) clusters. There are 2 parallel trees in the inventory representing the **role** of the servers plus their **location**. That way we have the flexibility to reassign a server from one cluster to another without modifying its location definition (if we imagine such move).

Consider this diff:
```
--- inventory/group_vars/rack_1.yml
+++ inventory/group_vars/rack_1.yml
-max_slots: 50
+max_slots: 50
+ceph_version: 19
```
The end result considering the hosts is correct (at the moment) but if we imagine a move as described above the mistake could be revealed and cause great damage ! Such flaws could already exist or introduced as inventory evolves and reviewing yaml is really hard/boring.

To tackle this problem we could use/build a kind of mapping between variables and the level in the inventory tree where it makes sense to encounter a definition. This is the **cartography**. To refer to the group_vars in a specific level without enumerating all, the idea is to introduce **descriptive** levels/group_vars, fully virtual and holding no data but usable by the tool.

The result of this idea applied to the same inventory as ```inventory/``` is in ```inventory_refined/```. Introducing the descriptive levels, the role tree for example went from
```
    cluster_1:
      hosts:
        server_01: {}
        server_02: {}
        server_03: {}
```
to
```
    cluster:
      children:
        cluster_1:
          hosts:
            server_01: {}
            server_02: {}
            server_03: {}
```
The cartography can also be found at ```inventory_refined/cartography.yml``` and the tool can be used like so :
```
x:~/Desktop/ansible-mercator$ uv run ansible-mercator --group_vars examples/inventory_refined/group_vars --inventory examples/inventory_refined/inventory.yml --cartography examples/inventory_refined/cartography.yml 

all good
```
If we introduce the above flaw we get
```
x:~/Desktop/ansible-mercator$ uv run ansible-mercator --group_vars examples/inventory_refined/group_vars --inventory examples/inventory_refined/inventory.yml --cartography examples/inventory_refined/cartography.yml 

ERROR: INCORRECT LOCATION ceph_version in rack_1.yml
```
