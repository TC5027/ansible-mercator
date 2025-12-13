# ansible-mercator

A CLI tool that ensures your Ansible variables are defined where they should be.

Have a look at the examples we have.

## Known limitations

* Because it is currently impossible to query the variables defined in a specific group_vars using the Ansible Python library, not all format of inventory are supported

* Files are expected to use '''.yml''' and not '''.yaml''', support for both will come
