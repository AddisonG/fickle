# Fickle
My personal webserver - a perfect mix of the unreliable and reliable.

## Designed to fail
Fickle is meant to be run cheaply - on a spot fleet with a target capacity
of exactly one. If it dies, it should come back and look exactly the same.

## Highlander

There can only be one Fickle at a time. It is tied to the server IP address.

## Anatomy

Fickle is just an ordinary EC2 instance, usually an Ubuntu Image.

Any server can become Fickle after running the `/boot/userdata.sh` script, but
it should probably only be run on instance start. Thus, this userdata script
is usually copied into a launch template user data.

The userdata script does a few things, but most critically it:
 - Attaches the FickleVolume, and mounts it at `/home/fickle`
 - Runs the boot script
 - Gives Fickle an IP address

The boot script is separate from the userdata script because the userdata
script must not be excessively large, and it is annoying to change.

The boot script changes more often, and does a variety of tasks, such as
creating users and groups, installing things, and setting up the instance.

The most important thing it does is bind mounts an overlay FS over `/etc/`.

## Overlay FS Bind Mount
This, simply speaking, means that changes to `/etc/` are NOT written to the
underlying Ubuntu image. They are instead written to a directory on the
FickleVolume, so that they are never lost. This is done so that application
and system config are saved, but not application files, as they can easily
be downloaded again.

## Git
This git repo sits on the home directory (`/home/fickle/`) of the server.
