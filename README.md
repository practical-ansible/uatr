# Ugly ansible test runner

A helper that verifies compatibility of your role with real world. Also allows kind of test driven development when creating ansible roles.

It is probably not a good idea to use this, it was created as a proof of concept. Also, it does not do any assertions, but just runs the role against a docker container.

## Requirements

* Have bash
* Have docker installed

## Installation

Link the uatr as a git submodule

## Usage

1. Create a folder named `test-{your-test-name}`. The test runner looks for folders of this name.
2. Create file called playbook.yml and define your test scenario as a playbook.
3. Run it

```shell
uatr
```

## Debugging

If you want to inspect what was created, there is a feature just for you.

```shell
uatr inspect
```

The test runner will then keep the container running and you can connect to it using 

```shell
docker port hosting-test
# Find the port forwarded to connect with ssh
ssh test@127.0.0.1 -p{port}
```
