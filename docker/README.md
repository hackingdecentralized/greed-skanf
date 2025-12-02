# Dockerfile for Greed

## Build
```bash
docker build --progress plain -t greed-env .
```
Note that the building of the docker image might take a few minutes.


## Usage
### Running a Container
Running persistent docker container and entering shell:
```bash
docker run -it greed-env
```

Optionally with a mounted volume for easier working
```bash
docker run -it -v ./shared:/home/greed/shared:rw greed-env
```

### Using Greed inside the container

After running a container don't forget to activate the venv.
(run this inside /home/greed)
```
source greed-venv/bin/activate
```

### Important locations

`/home/greed` -> location of greed installation
`/home/greed/gigahorse-toolchain` -> location of Gigahorse
`/home/souffle` -> location of Souffle