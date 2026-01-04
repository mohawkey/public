container=docker-011

lxc config set $container security.nesting=true
lxc config set $container security.syscalls.intercept.setxattr=true
lxc config set $container security.syscalls.intercept.mknod=true
lxc restart $container
