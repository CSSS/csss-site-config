# Other Services

These are services that can't be run as cronjobs due to various reasons.
This file should be updated every time a service is created or removed from the repository.

## Usage
1. You'll need to create a `.service` file and a `.timer` file. Place these in their own directory to keep everything neat.
```
services/
├── README.md <- You are reading this.
└── <your-service>/
    ├── <your-service>.service <- what actually runs
    └── <your-service>.timer   <- how often it should run
```

2. On the server (as root), copy the files and give them permissions:
```sh
install -m \
    0644 /path/to/services/<your-service>/<your-service>.service \
    /etc/systemd/system/<your-service>.service


install -m \
    0644 /path/to/services/<your-service>/<your-service>.timer \
    /etc/systemd/system/<your-service>.timer
```

3. Restart the daemon and enable the service.
```sh

systemctl daemon-reload
systemctl enable --now <your-service>.timer
```

- Optional: you can also run `install-services.sh`.

## Services

These are the currently active services:

### [TransLink Static Schedule](translink-static-schedule/translink-static-schedule.service)

Fetches the static schedule every Friday at 11PM America/Vancouver time.
In here because cronjobs can't handle timezones.
