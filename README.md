## Installation (Easy mode - For development environments)

### Prerequisites

 * Latest version of Docker ([download](https://docs.docker.com/get-docker)).
 * Latest version of Docker Compose ([download](https://docs.docker.com/compose/install))
 
 If you are on Windows Docker Compose is already included, you do not need to install it yourself.
 If you are on Linux/MacOS you can probably use your package manager.

### Windows development environment

It is recommended to work exclusively inside of WSL for performance and compatibility reasons. You can use something like [Remote Development for VSCode](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack) for this. All following instructions will assume that you are in a Linux environment.

### Installation

1. Install the [prerequisites](#prerequisites) to your host.
1. If on Windows, [set up WSL 2](https://learn.microsoft.com/en-us/windows/wsl/install) and open a terminal.
1. [Install git](https://git-scm.com/download/linux).
1. Clone the repo with `git clone https://github.com/e621ng/e621ng.git`.
1. `cd` into the repo.
1. Copy the sample environment file with `cp .env.sample .env`.
1. Run the following commands:
    ```
    docker compose run --rm -e SEED_POST_COUNT=100 e621 /app/bin/setup
    docker compose up
    ```
    After running the commands once only `docker compose up` is needed to bring up the containers.
1. To confirm the installation worked, open the web browser of your choice and enter `http://localhost:3000` into the address bar and see if the website loads correctly. An admin account has been created automatically, the username and password are `admin` and `e621test` respectively.

Note: When gems or js packages are updated you need to execute `docker compose build` to reflect them in the container.

#### <a id="docker-troubleshooting"></a>I followed the above instructions but it doesn't work, what should I do?

Try this:

1. `docker compose down -v` to remove all volumes.
1. `docker compose build --no-cache` to rebuild the image from scratch.
1. Follow the [instructions](#installation) starting from step 7.

#### <a id="development-tools"></a>Things to aid you during development

`docker compose run --rm tests` to execute the test suite.

`docker compose run --rm rubocop` to run the linter.

The postgres server accepts outside connections which you can use to access it with a local client. Use `localhost:34517` to connect to a database named `e621_development` with the user `e621`. Leave the password blank, anything will work.

#### Ruby LSP

This repo comes with [Ruby LSP](https://github.com/Shopify/ruby-lsp) preconfigured, install its [VSCode extension](https://marketplace.visualstudio.com/items?itemName=Shopify.ruby-lsp) and follow the instructions if you want to make use of it. The only requirement is that the Ruby version used by e621 is installed.

I recommend [rbenv](https://github.com/rbenv/rbenv) to manage your Ruby versions:

1. Install rbenv with [rbenv-installer](https://github.com/rbenv/rbenv-installer), or follow the [installation instructions](https://github.com/rbenv/rbenv#installation) on the rbenv repo.
1. Install the [necessary dependencies](https://github.com/rbenv/ruby-build/wiki#suggested-build-environment) to build ruby.
1. Run `rbenv install`
1. Install dependencies needed for bundler to install all gems. You can get an idea of those from the [Dockerfile](https://github.com/e621ng/e621ng/blob/master/Dockerfile#L3).  
For Ubuntu and derivatives you can just run `apt install cmake pkg-config libpq-dev`.
1. Run `bundle install` to validate that everything can install correctly.
1. Restart VSCode for good measure and you should be ready to go.

## Production Setup

Installation follows the same steps as the docker compose file. Ubuntu 20.04 is the current installation target.
There is no script that performs these steps for you, as you need to split them up to match your infrastructure.
Running a single machine install in production is possible, but is likely to be somewhat sluggish due to contention in disk between postgresql and opensearch.
Minimum RAM is 4GB. You will need to adjust values in config files to match how much RAM is available.
If you are targeting more than a hundred thousand posts and reasonable user volumes, you probably want to procure yourself a database server. See tuning guides for postgresql and opensearch for help planning these requirements.

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
