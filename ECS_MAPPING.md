# Mapping Pacman log lines to Elastic Common Schema

This document explains the way we map different types of Pacman log lines to the [Elastic Common Schema (ECS)](https://www.elastic.co/docs/reference/ecs) fields.

The general format of a Pacman log line is `[TIMESTAMP_ISO8601] [PREFIX] MESSAGE`, e.g.:
```
[2026-05-14T07:30:01+0300] [ALPM] installed python (3.14.5-1)
```
For more information, see [lib/libalpm/log.c](https://gitlab.archlinux.org/pacman/pacman/-/blob/master/lib/libalpm/log.c) in the [Pacman repository](https://gitlab.archlinux.org/pacman/pacman/).
Log levels can be found in [lib/libalpm/alpm.h](https://gitlab.archlinux.org/pacman/pacman/-/blob/master/lib/libalpm/alpm.h?ref_type=heads#L1489) and
[src/pacman/util.c](https://gitlab.archlinux.org/pacman/pacman/-/blob/master/src/pacman/util.c?ref_type=heads#L1857).

The log prefix is `PACMAN`, `ALPM`, or `ALPM-SCRIPTLET`.
Below we describe the mappings for different log lines for each of these prefixes.

Note: The mappings below are based on the log lines that we have encountered and it is not an exhaustive list.
Log lines that are not matched by any of the Logstash filters are still kept in the `message` field.
New mappings may be added in the future as we encounter new types of log lines.



## Common fields

The following fields have default values for all log lines, unless specified otherwise:
```
event.kind: "event"
event.dataset: "pacman.log"
event.original: <raw line>
message: <log line without timestamp and prefix>
log.file.path: "/var/log/pacman.log"
```
Note: `log.level` is only set for log messages that indicate a warning, error, or debug message.
Neither Pacman nor the ALPM library explicitly specify the log level.

`/var/log/pacman.log` is the default file path for Pacman logs, but it can be overridden in `pacman.conf`.
The `log.file.path` field contains the file path where Logstash takes the logs from.

The timestamp in the log line is mapped to the `@timestamp` field.
The timestamp created by Logstash is mapped to the `event.created` field.



## Design notes

We use `labels.*` namespace for storing additional (but less relevant) information for which there is no suitable ECS field,
such as transaction/build hook names, mkinitcpio presets, kernel version etc.
Since most information can be logically mapped to ECS fields, it is not worth defining separate custom namespaces.

For process-like log messages (e.g. running a `pacman` command, or ALPM scriptlet logging `dkms`/`depmod`/`mkinitcpio` commands)
we include additional `event.category` value of "process" next to the default category.
As a result, a KQL query like `event.category: "process"` can get all process-like lines (which have fields from the `process.*` namespace),
while KQL queries for the default categories (e.g. `event.category: "package"` or `event.category: "configuration"`) will not lose those events.

Furthermore, `process.name` and `process.args[0]` contain the process name as logged, which is not necessarily the absolute path to the executable.
Since the event is semantically process-like, we preserve the logged process name rather than trying to guess its absolute path.



## PACMAN

The prefix `PACMAN` corresponds to the frontend that interacts with the Arch Linux Package Management (ALPM) library.

We have encountered the following types of log lines from the Pacman frontend:
- Running a `pacman` command (e.g. `pacman -Syu` to perform a system upgrade,
`pacman -S --needed <package|group>` to install a package/group, or
`pacman -Rs <package|group>` to remove a package/group)
- Synchronizing package lists/databases
- Starting a full system upgrade

Note: the prefix `PACMAN` is used as the `event.provider` field, i.e.:
```
event.provider: "pacman"
```

The default value for `event.category` is "package", i.e.:
```
event.category: ["package"]
```


### Running pacman command

Example format:
```
[2026-05-14T07:30:00+0300] [PACMAN] Running 'pacman -Syu'
```

ECS mapping:
```
event.action: "pacman-command"
event.category: ["package","process"]
event.type: ["start"]

process.command_line: "pacman -Syu"
process.args: ["pacman", "-Syu"]
process.name: "pacman"
process.args_count: 2
```


### Synchronizing package lists/databases

Example format:
```
[2026-05-14T07:30:00+0300] [PACMAN] synchronizing package lists
```

ECS mapping:
```
event.action: "package-database-sync"
event.category: ["package"]
event.type: ["info"]
```


### Starting full system upgrade

Example format:
```
[2026-05-14T07:30:00+0300] [PACMAN] starting full system upgrade
```

ECS mapping:
```
event.action: "system-upgrade-started"
event.category: ["package"]
event.type: ["start"]
```


## ALPM

The prefix `ALPM` corresponds to the (backend) package management library used by `pacman`.

We have encountered the following types of log lines from the ALPM library (`libalpm`):
- Performing a package operation (install, reinstall, remove, upgrade, downgrade)
- Reporting transaction status (started, completed, failed, interrupted)
- Running a transaction hook (i.e. a transaction-triggered file under `/usr/share/libalpm/hooks`,
such as `30-update-mime-database.hook`, `70-dkms-install.hook`, `90-mkinitcpio-install.hook`,
or a file from additionally configured hook directories)
- Logging warning, error, or debug messages (`alpm.h` also defines `ALPM_LOG_FUNCTION` level, but we have not encountered it)

Note: the prefix `ALPM` is used as the `event.provider` field, i.e.:
```
event.provider: "alpm"
```

The default value for `event.category` is "package", i.e.:
```
event.category: ["package"]
```


### Performing package operation

#### Install

Example format:
```
[2026-05-14T07:30:01+0300] [ALPM] installed python (3.14.5-1)
```

ECS mapping:
```
event.action: "package-installed"
event.category: ["package"]
event.type: ["installation"]

package.name: "python"
package.version: "3.14.5-1"
```

#### Reinstall

Example format:
```
[2026-05-14T07:30:02+0300] [ALPM] reinstalled go (2:1.26.3-1)
```

ECS mapping:
```
event.action: "package-reinstalled"
event.category: ["package"]
event.type: ["installation"]

package.name: "go"
package.version: "2:1.26.3-1"
```

#### Remove

Example format:
```
[2026-05-14T07:30:03+0300] [ALPM] removed nodejs (26.1.0-1)
```

ECS mapping:
```
event.action: "package-removed"
event.category: ["package"]
event.type: ["deletion"]

package.name: "nodejs"
package.version: "26.1.0-1"
```

#### Upgrade

Example format:
```
[2026-05-14T07:30:04+0300] [ALPM] upgraded curl (8.20.0-5 -> 8.20.0-6)
```

ECS mapping:
```
event.action: "package-upgraded"
event.category: ["package"]
event.type: ["change"]

package.name: "curl"
package.version: "8.20.0-6"
labels.package_previous_version: "8.20.0-5"
```

#### Downgrade

Example format:
```
[2026-05-14T07:30:05+0300] [ALPM] downgraded wget (1.25.0-4 -> 1.25.0-3)
```

ECS mapping:
```
event.action: "package-downgraded"
event.category: ["package"]
event.type: ["change"]

package.name: "wget"
package.version: "1.25.0-3"
labels.package_previous_version: "1.25.0-4"
```


### Reporting transaction status

#### Start

Example format:
```
[2026-05-14T07:30:06+0300] [ALPM] transaction started
```

ECS mapping:
```
event.action: "transaction-started"
event.category: ["package"]
event.type: ["start"]
```

#### Complete

Example format:
```
[2026-05-14T07:30:07+0300] [ALPM] transaction completed
```

ECS mapping:
```
event.action: "transaction-completed"
event.category: ["package"]
event.type: ["end"]
event.outcome: "success"
```

#### Fail

Example format:
```
[2026-05-14T07:30:08+0300] [ALPM] transaction failed
```

ECS mapping:
```
event.action: "transaction-failed"
event.category: ["package"]
event.type: ["end"]
event.outcome: "failure"
```

#### Interrupt

Example format:
```
[2026-05-14T07:30:09+0300] [ALPM] transaction interrupted
```

ECS mapping:
```
event.action: "transaction-interrupted"
event.category: ["package"]
event.type: ["end"]
event.outcome: "failure"
```


### Running transaction hook

Example format:
```
[2026-05-14T07:30:10+0300] [ALPM] running '90-mkinitcpio-install.hook'...
```

ECS mapping:
```
event.action: "transaction-hook"
event.category: ["configuration"]
event.type: ["info"]

labels.hook_name: "90-mkinitcpio-install.hook"
labels.hook_type: "transaction"
```


### Logging warning, error, or debug messages

#### Warnings

Example format:
```
[2026-05-14T07:30:11+0300] [ALPM] warning: /etc/mkinitcpio.conf installed as /etc/mkinitcpio.conf.pacnew
```

ECS mapping:
```
event.action: "alpm-log-warning"
event.category: ["package"]
event.type: ["info"]
log.level: "warning"
message: "/etc/mkinitcpio.conf installed as /etc/mkinitcpio.conf.pacnew"
```
Note: the `message` field does not contain the prefix "warning: ".

#### Errors

Example format:
```
[2026-05-14T07:30:13+0300] [ALPM] error: unresolvable package conflicts detected
```

ECS mapping:
```
event.action: "alpm-log-error"
event.category: ["package"]
event.type: ["error"]
log.level: "error"
message: "unresolvable package conflicts detected"
```
Note: the `message` field does not contain the prefix "error: ".

#### Debug

Example format:
```
[2026-05-14T07:30:12+0300] [ALPM] debug: running ldconfig
```

ECS mapping:
```
event.action: "alpm-log-debug"
event.category: ["package"]
event.type: ["info"]
log.level: "debug"
message: "running ldconfig"
```
Note: the `message` field does not contain the prefix "debug: ".



## ALPM-SCRIPTLET

The prefix `ALPM-SCRIPTLET` corresponds to the output from package scriptlets (shell functions) and other hook/scriptlet commands executed during a transaction
(such as `pre_install`, `post_install`, `pre_upgrade`, `post_upgrade`, `pre_remove`, and `post_remove` scriptlets).

The output of `ALPM-SCRIPTLET` is mostly unstructured, so we have decided to process only the following types of log lines:
- Running a command (`dkms`, `depmod` or `mkinitcpio`; for `mkinitcpio`, only the command-line options are logged)
- Running a build hook (e.g. `base`, `udev`, `modconf`, `kms`, `encrypt`, `fsck`)
- Creating a user or a group (e.g. `dbus`, `vboxusers`)
- Creating a symlink (e.g. `/etc/systemd/user/sockets.target.wants/pipewire.socket` --> `/usr/lib/systemd/user/pipewire.socket`)
- Building image (initial ramdisk environment) from preset (such as `default` for `/etc/mkinitcpio.d/linux.preset`)
- Starting image build (e.g. `6.1.54-1-lts`, `6.5.4-hardened1-1-hardened`)
- Logging warning or error messages

Note: the prefix `ALPM-SCRIPTLET` is used as the `event.provider` field, i.e.:
```
event.provider: "alpm-scriptlet"
```

The default value for `event.category` is "configuration", i.e.:
```
event.category: ["configuration"]
```


### Running command

#### dkms

Example format:
```
[2026-05-14T07:40:01+0300] [ALPM-SCRIPTLET] ==> dkms install --no-depmod nvidia/595.71.05 -k 7.0.6-hardened1-1-hardened
```

ECS mapping:
```
event.action: "dkms-command"
event.category: ["configuration", "process"]
event.type: ["start"]

process.command_line: "dkms install --no-depmod nvidia/595.71.05 -k 7.0.6-hardened1-1-hardened"
process.args: ["dkms","install","--no-depmod","nvidia/595.71.05","-k","7.0.6-hardened1-1-hardened"]
process.name: "dkms"
process.args_count: 6
```

#### depmod

Example format:
```
[2026-05-14T07:40:02+0300] [ALPM-SCRIPTLET] ==> depmod 7.0.6-hardened1-1-hardened
```

ECS mapping:
```
event.action: "depmod-command"
event.category: ["configuration", "process"]
event.type: ["start"]

process.command_line: "depmod 7.0.6-hardened1-1-hardened"
process.args: ["depmod","7.0.6-hardened1-1-hardened"]
process.name: "depmod"
process.args_count: 2
```

#### mkinitcpio options

Example format:
```
[2026-05-14T07:40:03+0300] [ALPM-SCRIPTLET]   -> -k /boot/vmlinuz-linux-hardened -g /boot/initramfs-linux-hardened.img
```

ECS mapping:
```
event.action: "mkinitcpio-command"
event.category: ["configuration", "process"]
event.type: ["start"]

process.command_line: "mkinitcpio -k /boot/vmlinuz-linux-hardened -g /boot/initramfs-linux-hardened.img"
process.args: ["mkinitcpio","-k","/boot/vmlinuz-linux-hardened","-g","/boot/initramfs-linux-hardened.img"]
process.name: "mkinitcpio"
process.args_count: 5
```
Note: `mkinitcpio` is not part of the log line; it is added to the `process.*` fields for completeness.


### Running build hook

Example format:
```
[2026-05-14T07:40:04+0300] [ALPM-SCRIPTLET]   -> Running build hook: [base]
```

ECS mapping:
```
event.action: "build-hook"
event.category: ["configuration"]
event.type: ["info"]

labels.hook_name: "base"
labels.hook_type: "build"
```


### Creating user or group

#### Users

Example format:
```
[2026-05-14T07:40:13+0300] [ALPM-SCRIPTLET] Creating user 'dbus' (System Message Bus) with UID 81 and GID 81.
```

ECS mapping:
```
event.action: "user-created"
event.category: ["iam"]
event.type: ["user","creation"]

user.target.name: "dbus"
user.target.full_name: "System Message Bus"
user.target.id: "81"
user.target.group.id: "81"
```
Note: ECS defines `user.target.*` field set for the targeted user of the taken action.

#### Groups

Example format:
```
[2026-05-14T07:40:12+0300] [ALPM-SCRIPTLET] Creating group 'dbus' with GID 81.
```

ECS mapping:
```
event.action: "group-created"
event.category: ["iam"]
event.type: ["group","creation"]

group.name: "dbus"
group.id: "81"
```
Note: ECS does not define `group.target.*` field set for the targeted group of the taken action.


### Creating symlink

Example format:
```
[2026-05-14T07:40:11+0300] [ALPM-SCRIPTLET] Created symlink /etc/systemd/user/sockets.target.wants/pipewire.socket → /usr/lib/systemd/user/pipewire.socket.
```

ECS mapping:
```
event.action: "symlink-created"
event.category: ["file"]
event.type: ["creation"]

file.type: "symlink"
file.path: "/etc/systemd/user/sockets.target.wants/pipewire.socket"
file.target_path: "/usr/lib/systemd/user/pipewire.socket"
```


### Building initial ramdisk environment

#### Building image from preset

Example format:
```
[2026-05-14T07:40:05+0300] [ALPM-SCRIPTLET] ==> Building image from preset: /etc/mkinitcpio.d/linux-hardened.preset: 'default'
```

ECS mapping:
```
event.action: "mkinitcpio-build-preset"
event.category: ["configuration"]
event.type: ["info"]

labels.mkinitcpio_preset_file: "/etc/mkinitcpio.d/linux-hardened.preset"
labels.mkinitcpio_preset_name: "default"
```

#### Starting image build 

Example format:
```
[2026-05-14T07:40:07+0300] [ALPM-SCRIPTLET] ==> Starting build: '7.0.6-hardened1-1-hardened'
```

ECS mapping:
```
event.action: "ramdisk-build-started"
event.category: ["configuration"]
event.type: ["start"]

labels.kernel_version: "7.0.6-hardened1-1-hardened"
```


### Logging warning or error messages

#### Warnings

Example format:
```
[2026-05-14T07:40:16+0300] [ALPM-SCRIPTLET] ==> WARNING: Possibly missing firmware for module: 'xhci_pci'
```

ECS mapping:
```
event.action: "alpm-scriptlet-log-warning"
event.category: ["configuration"]
event.type: ["info"]
log.level: "warning"
message: "Possibly missing firmware for module: 'xhci_pci'"
```
Note: the `message` field does not contain the prefix "==> WARNING: ".

#### Errors

Example format:
```
[2026-05-14T07:40:17+0300] [ALPM-SCRIPTLET] ==> ERROR: Missing 6.12.4-arch1-1 kernel headers for module vboxhost/7.1.4_OSE.
```

ECS mapping:
```
event.action: "alpm-scriptlet-log-error"
event.category: ["configuration"]
event.type: ["error"]
log.level: "error"
message: "Missing 6.12.4-arch1-1 kernel headers for module vboxhost/7.1.4_OSE."
```
Note: the `message` field does not contain the prefix "==> ERROR: ".


### Default

ECS mapping:
```
event.action: "alpm-scriptlet-output"
event.category: ["configuration"]
event.type: ["info"]
```
Note: "configuration" is used as the default value for `event.category` for `ALPM-SCRIPTLET`.
It may not always represent the most semantically correct value.
