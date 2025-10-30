<div align="center">
  <img src="public/images/github-logo.svg" width="150" height="150" align="left">
  <div align="left">
    <h3>E621</h3>
    <a href="https://github.com/e621ng/e621ng/releases">
      <img src="https://img.shields.io/github/v/release/e621ng/e621ng?label=version&style=flat-square" alt="Releases" />
    </a><br />
    <a href="https://github.com/e621ng/e621ng/issues">
      <img src="https://img.shields.io/github/issues/e621ng/e621ng?label=open%20issues&style=flat-square" alt="Issues" />
    </a><br />
    <a href="https://github.com/e621ng/e621ng/pulls">
      <img src="https://img.shields.io/github/issues-pr/e621ng/e621ng?style=flat-square" alt="Pull Requests" />
    </a><br />
    <a href="https://github.com/e621ng/e621ng/commits/master/">
      <img src="https://img.shields.io/github/check-runs/e621ng/e621ng/master?style=flat-square" alt="GitHub branch check runs" />
    </a><br />
  </div>
</div>
<br />


## Installation (Easy mode - For development environments)

### Prerequisites

 * Latest version of Docker ([download](https://docs.docker.com/get-docker)).
 * Latest version of Docker Compose ([download](https://docs.docker.com/compose/install))
 * Git ([download](https://git-scm.com/downloads))
 
 If you are on Windows Docker Compose is already included, you do not need to install it yourself.
 If you are on Linux/MacOS you can probably use your package manager.

### Installation

1. Download and install the [prerequisites](#prerequisites).
1. Clone the repo with `git clone https://github.com/e621ng/e621ng.git`.
1. `cd` into the repo.
1. Copy the sample environment file with `cp .env.sample .env`.
1. WSL Only: Run the following commands:
    ```
    git config core.fileMode false
    cp -ru hooks/ .git
    ```
    This will resolve permission issues, and set up a hook that will reset file permissions to what they are supposed to be in the future.  
    If you are not using WSL, this is likely not a problem for you.
1. Run the following commands:
    ```
    docker compose run --rm e621 /app/bin/setup
    docker compose up
    ```
    After running the commands once only `docker compose up` is needed to bring up the containers.
1. To confirm the installation worked, open the web browser of your choice and enter `http://localhost:3000` into the address bar and see if the website loads correctly. An admin account has been created automatically, the username and password are `admin` and `hexerade` respectively.
1. By default, the site will lack any content. For testing purposes, you can generate some using the following command:
    ```
    docker exec -it e621ng-e621-1 /app/bin/populate
    ```
    The command can be run multiple times to generate more content.  
    Environmental variables are available to customize what kind of content is generated.

Note: When gems or js packages are updated you need to execute `docker compose build` to reflect them in the container.

### Local DText gem

You may want to test changes made to the [DText gem](https://github.com/e621ng/dtext) on a local instance.
You are recommended to reconsider and rethink your life choices.

If you are sure that you want to do this, follow these steps.

1. Clone the repo into a `vendor` directory. Example: `~/e621ng/vendor/dtext/`.
   1. `cd ~/e621ng`
   2. `mkdir vendor && cd vendor`
   3. `git clone https://github.com/e621ng/dtext.git` (substitute your local fork as needed)
2. Rebuild the container
   1. `cd ~/e621ng`
   2. `docker compose build --no-cache`
3. Reset the Gemfile.lock: `git checkout HEAD -- Gemfile.lock`  
  This is not required, but it will prevent you from accidentally committing bad changes.
4. Set `LOCAL_DTEXT=true` in the `.env` file.

At this point, the DText repository is set up.
It will be automatically compiled whenever the docker container is started.

It is recommended to set `LOCAL_DTEXT` to `false` whenever you are not actively working on anything related to the DText repo, and then rebuild the container.

### Development environment

This repo provides a Dev Container configuration. You can use something like the [Dev Container extension for VSCode](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) to make use of it. Simply install it, open the folder in VSCode, and click the button in the bottom right to open the folder in the Dev Container.

#### <a id="docker-troubleshooting"></a>I followed the above instructions but it doesn't work, what should I do?

Try this:

1. `docker compose down -v` to remove all volumes.
1. `docker compose build --no-cache` to rebuild the image from scratch.
1. Follow the [instructions](#installation) starting from step 5.

#### <a id="windows-executable-bit"></a>Why are there a bunch of changes I can't revert?

You're most likely using Windows. Give this a shot, it tells Git to stop tracking file mode changes:

`git config core.fileMode false`

#### <a id="development-tools"></a>Things to aid you during development

`docker compose run --rm tests` to execute the test suite.

`docker compose run --rm rubocop` to run the linter.

The postgres server accepts outside connections which you can use to access it with a local client. Use `localhost:34517` to connect to a database named `e621_development` with the user `e621`. Leave the password blank, anything will work.

#### Truenas / Local Server Installation

If you decide to deploy this docker image to an external / local server, you do need to remember to change the DANBOORU_HOST variable in the docker-compose.yml file to the IP of your server. Otherwise, you will not be able to access it, or the image links will be broken. 

Specifically for Truenas/NAS boxes users: you need to use the shell itself to set the repo up, you can then manage the images/variable/config with Portainer/Dockge after it's set up.

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
