# cron-letsencrypt-nat

> Cron-able script(s) for automated letsencrypt management.

These two scripts make it even simpler to set up *and renew* your letsencrypt certificates.

The use case is this:
- You want to put it into a crontab and forget about it.
- You want the certificate to be in a git repository that automatically gets pushed to your internal git server.
- You're behind a NAT, so the renew script can use an unprivileged port (like 12345). (Or you just don't care and run on port 80.)

## Table of Contents

- [Install](#install)
- [Usage](#usage)
  - [Setup](#setup)
  - [Renewals](#renewals)
- [Safety & Security](#safety--security)
- [TODOs](#todos)
- [NOTDOs](#notdos)
- [Contribute](#contribute)

## Install

`apt-get install python3 acme-tiny openssl coreutils`

- `acme-tiny`: Because it's small, I read and approve of the code, and it's in the Debian distro. (Technically I use Raspbian, but there shouldn't be any significat difference to Ubuntu or Vanilla Debian.)
- `openssl`: Needed only during setup, for the generation of the private keys and cert signing request.
- `python3`: Because acme-tiny depends on it anyway, and because I use it as a *temporary* HTTP server.
- `coreutils`: Contains `timeout`, and is probably installed anyway. `timeout` helps ensuring that the temporary HTTP server is *temporary*. Also, `mktemp`, which is used to create the temporary http server directory. Also, `shuf` and `sleep`, which provide a randomized delay on startup.

## Usage

### Setup

Just call `/path/to/setup.sh my.example.com` and be done with it.
The working directory doesn't matter.

The setup creates a subdirectory with the necessary files:
```
$ ls -A my.example.com
FIXME
```

The setup will then attempt to push it to your git server at `ssh://private_git`.
If your internal git server doesn't happen to be located at
`ssh://private_git`, then you need to run these commands in the directory `./my.example.com/`:
```
git remote set-url origin ssh://${your_server_here}/cert-${domain}.git
```
Alternatively you can create a ssh-alias for `private_git` using [`ssh_config`](https://www.ssh.com/ssh/config/).

### Renewals

Just call `IMPATIENT=1 /path/to/renew.sh my.example.com 12345` with the correct domain and local port, and be done with it.
(The `IMPATIENT=1` removes the wait for a random amount of time, up to 23 hours.)

Or even better: Put something like this into your crontab, and never think about renewals again:
```
0 0 23 */2 * /home/pi/cron-letsencrypt-nat/renew.sh my.example.com 12345 # REPLACE DOMAIN AND NAT'D PORT!
```

Naturally, you should also check whether your crontab actually works. I like putting `* * * * * make some_noise` temporarily in a crontab to check that it actually reports errors.

You should re-roll the day-of-month; `shuf -i 1-28 -n1` could give you a suggestion.

If you really insist on *not* getting an e-mail when it's working fine (this practice is dangerous), then consider using `cronic`. In this case I *strongly* suggest that a *different* machine regularily checks your cert, for example `/usr/bin/faketime '+2weeks' curl -sS https://my.example.com/ > /dev/null`

## Safety & Security

### Safety (against accidents)

- If your entropy is bad during `setup.sh`, you're in a bad spot anyway. You could run `curl --proto '=https' --tlsv1.2 -sSf 'https://www.random.org/cgi-bin/randbyte?nbytes=16&format=f' > /dev/random` if that makes you happy.
- If your server isn't online 24/7, a cron entry like that is a bad idea. You could check whether `cert.pem` is fresh, and if not, run the script. That would be a nice addition to this repository. However, I have no need for it, so I don't write it.
- Because `renew.sh` waits for a random amount of time, it is very unlikely to hit "peak time" of letsencrypt, or get considered as flooding.
- Because `renew.sh` keeps the "http serve" files in a random directory and often checks for the state of the git repository, there is only little chance of an error, even if you manage to make it run twice simultaneously.
- It's a git repository, and the script only ever calls `git commit`, not `git commit --amend`. Due to the git repository and pushing it to the git server, irrecoverable data loss is extremely unlikely.
- In theory you need to restart Apache to apply the new certificate. In practice, at least on Raspbian, Apache reloads the configuration and certificate every day on it's own; no additional work necessary.

Plus all the "security" arguments:

### Security (against malicious actors)

- [Read](https://github.com/BenWiederhake/cron-letsencrypt-nat/blob/master/setup.sh) [the](https://github.com/BenWiederhake/cron-letsencrypt-nat/blob/master/renew.sh) [code](https://github.com/diafygi/acme-tiny/blob/master/acme_tiny.py). My shell scripts are only a few dozen lines, acme-tiny is tiny indeed, and if you don't trust git or openssl I can't help you.
- Obviously, be careful about permissions, especially with the folders and the git repository. No security can help if instead of a private secret private git repo you use a public github repo.
- If you insist on running this as root, you would run `acme-tiny.py` as root, which [they don't recommend](https://github.com/diafygi/acme-tiny#permissions).
- Theoretically `acme-tiny.py` [could](https://github.com/diafygi/acme-tiny#permissions) read your `domain.key`, but it [doesn't](https://github.com/diafygi/acme-tiny/blob/master/acme_tiny.py).
- Because `renew.sh` waits for a random amount of time, an attacker would have a hard time predicting when exactly to look at your port 80. And even if they correctly time it, the presence of an empty `index.html` file effectively disables listings. And even if the attacker guesses that correctly, they can merely prove that you're currently trying to verify yourself to Let's Encrypt, which is the whole point of this endeavor.
- `python3 -m http.server` is reasonably mature and well-maintained, and although it ["only implements basic security checks"](https://docs.python.org/3/library/http.server.html) like disallowing path traversal, there is not much more to get anyway.

## TODOs

I don't intend to change it much, once it runs.
This code is based on the script I've been using for years, so I expect it to work reasonably stable.

## NOTDOs

Here are some things this project will definitely not support:
* Integration specific to docker/k8s/azure/qubes/whatever.
* Anything that requires large amounts of code.
* Support for outdated or incompatible setups, like a system without any cron-like daemon. Because that's a different use case.
* Any languages other than `sh` (should run in `dash`) and Python 3.

Here are some unlikely things 
* Ultra-mega-high security paranoid stuff, if it interfers too much with usability. Dropping privileges some more would be nice though.

## Contribute

This is free and unencumbered software released into the public domain.

Feel free to dive in! [Open an issue](https://github.com/BenWiederhake/cron-letsencrypt-nat/issues/new) or submit PRs.
