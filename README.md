## Installation (Easy mode - For development environments)
#### Prerequisites
 * Latest version of VirtualBox and the VM Extension Pack ([download](https://www.virtualbox.org/wiki/Downloads))
 * Latest version of Vagrant ([download](https://www.vagrantup.com))

#### Installation
1. Download and install the prerequisites
2. Open Command Prompt/Terminal and run the following commands:
   ```
   vagrant plugin install vagrant-hostmanager
   vagrant plugin install vagrant-bindfs
   vagrant plugin install vagrant-vbguest
   ```
3. Download and extract the repo
4. `cd` into the repo using Command Prompt/Terminal
5. Run the following command:
     `vagrant up`
     On Windows you will need to run this as admin, otherwise symlink creation will not work.
6. This would be a good time to rewatch your favorite TV series installment, cook & have breakfast/lunch/dinner, walk the dog, clean your room, etc.<br>
By the time you get back the install will surely have completed.<sup>1</sup>
7. To confirm the installation worked, open the web browser of your choice and enter `http://e621.local` into the address bar and see if the website loads correctly.

<sub><sup>1</sup> If the install did not finish by the time an activity is complete please select another activity to avoid crippling boredom.</sub>

#### Development Database

The postgres server accepts outside connections which you can use to connect with a local client. Use `192.168.64.78:5432` to connect to a database named `danbooru2` with the user `danbooru`. Leave the password blank, anything will work.

## Vagrant Troubleshooting

See [Troubleshooting](Troubleshooting.md).

## Installation

Installation follows the same steps as the vagrant setup script. Ubuntu 20.04 is the current installation target.
There is no script that performs these steps for you, as you need to split them up to match your infrastructure.
Running a single machine install in production is possible, but is likely to be somewhat sluggish due to contention in disk between postgresql and elasticsearch.
Minimum RAM is 4GB. You will need to adjust values in config files to match how much RAM is available.
If you are targeting more than a hundred thousand posts and reasonable user volumes, you probably want to procure yourself a database server. See tuning guides for postgresql and elasticsearch for help planning these requirements.


There are some forks that contain full docker setups. If you are looking for a Docker deployment and don't want to wait for this repo to slowly get there, look into those.

## Troubleshooting

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

### IQDB Service

IQDB integration is delegated to the [IQDBS service](https://github.com/zwagoth/iqdbs).

### Cropped Thumbnails

There's optional support for cropped thumbnails. This relies on installing
`libvips-8.6` or higher and setting `Danbooru.config.enable_image_cropping`
to true.
