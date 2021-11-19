# go-micro

**go-micro** is a stripped-down fork of the opinionated *production-ready* RESTful JSON backend template [go-starter](https://github.com/allaboutapps/go-starter) written in [Go](https://golang.org/) by [allaboutapps](https://allaboutapps.at/). The aim of this fork is to create a base for stateless services to be used in a microservice architecture.


### Quickstart

Create a new git repository through the GitHub template repository feature ([use this template](https://github.com/mwieser/go-micro/generate)). You will then start with a **single initial commit** in your own repository. 

```bash
# Clone your new repository, cd into it, then easily start the docker-compose dev environment through our helper
./docker-helper.sh --up
```

You should be inside the 'service' docker container with a bash shell.

```bash
development@94242c61cf2b:/app$ # inside your container...

# Shortcut for make init, make build, make info and make test
make all

# Print all available make targets
make help
```

### Set project module name for your new project

To replace all occurrences of `mwieser.com/go-micro` (our internal module name of this project) with your desired projects' module name, do the following:

```bash
development@94242c61cf2b:/app$ # inside your container...

# Set a new go project module name.
make set-module-name
# allaboutapps.dev/<GIT_PROJECT>/<GIT_REPO> (internal only)
# github.com/<USER>/<PROJECT>
# e.g. github.com/majodev/my-service
```

The above command writes your new go module name to `tmp/.modulename`, `go.mod`. It actually sets it everywhere in `**/*` - thus this step is typically only required **once**. If you need to merge changes from the upstream go-starter later, we may want to run `make force-module-name` to set your own go module name everywhere again (especially relevant for new files / import paths).

Optionally you may want to move the original `README.md` and `LICENSE` away:

```bash
development@94242c61cf2b:/app$ # inside your container...

# Optionally you may want to move our LICENSE and README.md away.
mv README.md README-go-micro.md
mv LICENSE LICENSE-go-micro

# Optionally create a new README.md for your project.
make get-module-name > README.md
```

### Visual Studio Code

> If you are new to VSCode Remote - Containers feature, see [FAQ: How does our VSCode setup work?](https://github.com/allaboutapps/go-starter/wiki/FAQ#how-does-our-vscode-setup-work).

Run `CMD+SHIFT+P` `Go: Install/Update Tools` **after** attaching to the container with VSCode to auto-install all golang related vscode extensions.


### Building and testing

Other useful commands while developing your service:

```bash
development@94242c61cf2b:/app$ # inside your container...

# Print all available make targets
make help

# Shortcut for make init, make build, make info and make test
make all

# Init install/cache dependencies and install tools to bin
make init

# Rebuild only after changes to files (generate, format, build, lint)
make

# Execute all tests
make test
```

### Running 

To run the service locally you may:

```bash
development@94242c61cf2b:/app$ # inside your development container...

# First ensure you have a fresh `app` executable available
make build

# Check if all requirements for becoming are met (mnt path is writeable)
app probe readiness -v

# Start the locally-built server
app server

# Now available at http://127.0.0.1:8080

# You may also run all the above commands in a single command
app server --probe
```

### Uninstall

Simply run `./docker-helper --destroy` in your working directory (on your host machine) to wipe all docker related traces of this project (and its volumes!).
