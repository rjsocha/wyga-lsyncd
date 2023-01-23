# Lsynd as container
  
Configuration via env:

```
  CONFIGS - list of env variables containing configuration (comma separted)

  CONFIGURATION tags:

  SRC:  - source folder

  DST:  - URI of destination server in format:

    ssh://login@server[:port]/path

    Default port 22

  Only ssh:// URIs are supported. Can be provided as ENV: variable


  KEY:    - ssh key

    file name or ENV:VARIABLE - where variable should contins base64 encoded ssh's private key

  EXCLUDE: - comma seprated list of directories to exclude from sync

  DELAY:   - how often to synchronize files (by default 15)

  MAX-DELAYS: - configuration will aggregate events up to delay seconds or MAX-DELAYS separate uncollapsible events, which ever happens first. (by default 1000)
```

See docker-compose.yaml for example
