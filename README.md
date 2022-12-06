## Installation (Easy mode - For development environments)

### Prerequisites

 * Latest version of Docker ([download](https://docs.docker.com/get-docker)). The WSL2 backend on Windows is required.
 * Latest version of Docker Compose ([download](https://docs.docker.com/compose/install))
 * Git ([download](https://git-scm.com/downloads))
 
 If you are on Windows Docker Compose is already included, you do not need to install it yourself.
 If you are on Linux/MacOS you can probably use your package manager.

### Windows development environment

Developing on Windows requires some special setup to get good response times. Unfortunately performance across file systems is not great for WSL2 and recieving inotify events isn't possible. This leads to an all-around unpleasant experience. Read more about this [here](https://docs.docker.com/desktop/windows/wsl/#best-practices).

To mitigate this you can install a WSL distribution and clone the project inside there. Executing docker inside the container will still work, without directly accessing the host. Access the code with [Remote Development for VSCode](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack) or simply use the network address `\\wsl$`.

### Installation

1. Download and install the [prerequisites](#prerequisites).
1. Clone the repo with `git clone https://github.com/zwagoth/e621ng.git`.
1. `cd` into the repo.
1. Copy the sample environment file with `cp .env.sample .env`.
1. Uncomment the `COMPOSE_PROFILES` variable if you wish to use solargraph. Doesn't work on Windows without WSL.
1. Run the following commands:
    ```
    docker-compose run -e SEED_POST_COUNT=100 e621 /app/bin/setup
    docker-compose up
    ```
    After running the commands once only `docker-compose up` is needed to bring up the containers.
1. To confirm the installation worked, open the web browser of your choice and enter `http://localhost:3000` into the address bar and see if the website loads correctly. An admin account has been created automatically, the username and password are `admin` and `e621test` respectively.

Note: When gems or js packages are updated you need to execute `docker-compose build` to reflect them in the container.

#### <a id="docker-troubleshooting"></a>I followed the above instructions but it doesn't work, what should I do?

Try this:

1. `docker-compose down -v` to remove all volumes.
1. `docker-compose build --no-cache` to rebuild the image from scratch.
1. Follow the [instructions](#installation) starting from step 6.

#### <a id="development-tools"></a>Things to aid you during development

`docker-compose run --rm tests` to execute the test suite.

`docker-compose run --rm rubocop` to run the linter. Run it against changed files only, there are too many existing violations at the moment.

The postgres server accepts outside connections which you can use to access it with a local client. Use `localhost:34517` to connect to a database named `danbooru2` with the user `danbooru`. Leave the password blank, anything will work.

## Production Setup

Installation follows the same steps as the docker compose file. Ubuntu 20.04 is the current installation target.
There is no script that performs these steps for you, as you need to split them up to match your infrastructure.
Running a single machine install in production is possible, but is likely to be somewhat sluggish due to contention in disk between postgresql and elasticsearch.
Minimum RAM is 4GB. You will need to adjust values in config files to match how much RAM is available.
If you are targeting more than a hundred thousand posts and reasonable user volumes, you probably want to procure yourself a database server. See tuning guides for postgresql and elasticsearch for help planning these requirements.

### Production Troubleshooting

These instructions won't work for everyone. If your setup is not
working, here are the steps I usually recommend to people:

1) Test the database. Make sure you can connect to it using psql. Make
sure the tables exist. If this fails, you need to work on correctly
installing PostgreSQL, importing the initial schema, and running the
migrations.

2) Test the Rails database connection by using rails console. Run
Post.count to make sure Rails can connect to the database. If this
fails, you need to make sure your Danbooru configuration files are
correct.

3) Test Nginx to make sure it's working correctly.  You may need to
debug your Nginx configuration file.

4) Check all log files.
