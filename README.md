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


#### TrueNAS / Local Server Installation

If you decide to deploy this docker image to an external / local server, you do need to remember to change the DANBOORU_HOST variable in the docker-compose.yml file to the IP of your server. Otherwise, you will not be able to access it, or the image links will be broken. 

Specifically for TrueNAS/NAS boxes users: you need to use the shell itself to set the repo up, you can then manage the images/variable/config with Portainer/Dockge after it's set up.


### <a id="development-tools"></a>Testing and Linting

#### Testing Suite

The test suite runs in parallel using `parallel_tests`. Before running tests for the first time (or after a schema change), set up the parallel test databases:

```shell
docker compose run --rm --entrypoint bin/rake tests parallel:create
docker compose run --rm --entrypoint bin/rake tests parallel:load_schema
docker compose run --rm --entrypoint bin/rake tests parallel:seed
```

Then run the suite:

```shell
docker compose run --rm tests
```

This defaults to 4 parallel workers. Override with `PARALLEL_TEST_PROCESSORS`:

```shell
PARALLEL_TEST_PROCESSORS=8 docker compose run --rm tests
```

#### Linters

`docker compose run --rm rubocop` to lint the Ruby code
`docker compose run --rm linter` to lint JavaScript/TypeScript code

#### Database

The postgres server accepts outside connections which you can use to access it with a local client. Use `localhost:34517` to connect to a database named `e621_development` with the user `e621`. Leave the password blank, anything will work.

## Contributing

### Please follow the PR naming conventions
Prefix your PR with the primary subsystem being changed in square brackets (e.g. `[Posts] Tweak post search UI`), & use the imperative present tense (e.g. use `[Posts] Tweak the post search UI` instead of `[Posts] Tweaked the post search UI`).

### Please run the required checks locally prior to submission
Ensuring our checks pass prior to submission greatly increases the chances that your PR will be reviewed in a timely manner. There are 3 checks run on PRs; their local equivalents are:
* `docker compose run --rm tests`: Runs the test suite for the Ruby/Rails code
* `docker compose run --rm rubocop`: Runs the linter for the Ruby/Rails code
* `docker compose run --rm linter`: Runs the linter for the JavaScript/TypeScript code

### If addressing a preexisting issue, please reference it
For issues already submitted to GitHub, including the issue number in your PR title with the proper formatting (e.g. `[Posts] Tweak post search UI (#123)`) lets GitHub automatically link the two, allowing us to both see the full context of the problem & close the issue as solved automatically upon merging. If the issue is not on GitHub, linking to discussion about the issue lets our maintainers gauge the interest in the feature and the likelihood the PR sufficiently addresses the demands.

### Please limit the scope of your changes
If you are undertaking a large project, please submit/reference an issue describing the overall project, & break it down into smaller logical units that are submitted separately; this makes for dramatically easier & faster review (&, if need be, iteration), & reduces the merging burden for other contributors upon merging.

### Please add/update relevant tests
If you create a new public class or function, or alter the behavior of preexisting ones, adding and/or updating the relevant tests allows maintainers to have far more confidence in your code with far less review, increasing the chances at a speedy turnaround. We currently have [RSpec](https://rspec.info/) tests for our Ruby/Rails code, but until a test suite is configured for our JavaScript/TypeScript code, you don't need to worry about testing JavaScript/TypeScript code. We do have code coverage analytics, & while we don't strictly require that the overall coverage never decreases, that is an ideal we'd like to strive for.

### Please do not commit changes to `rubocop_todo.yml`, nor excessively use inline comments to silence lint errors/warnings
We have mechanisms to properly update the to-do file without causing frustrating conflicts, and you should not be hiding lint errors/warnings with this file. We ask that you avoid using in-line config comments to bypass the linter, although it is permissible in cases where the code's structure makes it impossible to do so without a substantial or needlessly convoluted refactoring effort (i.e. `TagQuery`'s `parse_query` method). Similarly to test coverage, while we don't strictly require that the overall number of lints ignored - through both inline comments & `rubocop_todo.yml` - never increases, that is an ideal we'd like to strive for.

### Please check for & review prior discussion regarding the goal of your PR, and any attempts to fix the same issues
This ensures you have a solid idea of the requirements for acceptance and the overall desire for the PR before starting work on it & submitting for approval.

## Production Setup

Installation follows the same steps as the docker compose file. Ubuntu 20.04 is the current installation target.
There is no script that performs these steps for you, as you need to split them up to match your infrastructure.
Running a single machine install in production is possible, but is likely to be somewhat sluggish due to contention in disk between PostgreSQL and OpenSearch.
Minimum RAM is 4GB. You will need to adjust values in config files to match how much RAM is available.
If you are targeting more than a hundred thousand posts and reasonable user volumes, you probably want to procure yourself a database server. See tuning guides for PostgreSQL and OpenSearch for help planning these requirements.

### Production Troubleshooting

These instructions won't work for everyone. If your setup is not
working, here are the steps I usually recommend to people:

1) Test the database. Make sure you can connect to it using `psql`. Make
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
