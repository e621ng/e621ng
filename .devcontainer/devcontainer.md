## Getting started
Similar to the steps in the README, you will want to run `bin/setup`. 
You may also want to run `bin/populate` to populate the database. 
** IMPORTANT ** If you are using an online devcontainer instance (such as GitHub Codespaces), it is **HIGHLY RECOMMENDED** that to modify 'db/populate.rb' to use e926 or specify 'rating:s' in the post population. Other modifications may also be nesessary to comply with their content policies.

## Common problems and solutions
### Container not opening
**Port already in use**: You have another instance of e621ng (or something else using the same port) open. Stop it, or you can try editing `.env.devcontainer`.
### Service failures
**`bin/setup` postgres duplicates**: If you don't want to rebuild, try running: `rails db:drop` and `rails db:prepare`
**`Procfile does not exist.`**: You may have run a `docker compose` command inside of the container. Run `apk del docker-cli-compose`, and then start the service manually. If this still doesn't work, you may need to rebuild (or even fully delete) the container.
### Docker issues
**Docker commands not working**: Try manually running `apk add bash-completion docker-cli`. It is possible they failed to run on container setup.
**Docker Compose not working**: Docker compose is not available in the container. `docker-cli-compose` causes the e621 service to be unable to find the `Procfile`.
