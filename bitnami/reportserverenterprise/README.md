# ReportServer Enterprise packaged by Bitnami

## What is ReportServer Enterprise?

> ReportServer is the enterprise business intelligence platform. It integrates multiple reporting engines, dashboards and ad-hoc analytics, with scripting capabilities to for deep customization..

[Overview of ReportServer Enterprise](https://reportserver.net)



## TL;DR

```console
$ curl -sSL https://raw.githubusercontent.com/bitnami/bitnami-docker-reportserverenterprise/master/docker-compose.yml > docker-compose.yml
$ docker-compose up -d
```

**Warning**: This quick setup is only intended for development environments. You are encouraged to change the insecure default credentials and check out the available configuration options in the [Environment Variables](#environment-variables) section for a more secure deployment.

## Why use Bitnami Images?

- Bitnami closely tracks upstream source changes and promptly publishes new versions of this image using our automated systems.
- With Bitnami images the latest bug fixes and features are available as soon as possible.
- Bitnami containers, virtual machines and cloud images use the same components and configuration approach - making it easy to switch between formats based on your project needs.
- All our images are based on [minideb](https://github.com/bitnami/minideb) a minimalist Debian based container image which gives you a small base container image and the familiarity of a leading Linux distribution.
- All Bitnami images available in Docker Hub are signed with [Docker Content Trust (DCT)](https://docs.docker.com/engine/security/trust/content_trust/). You can use `DOCKER_CONTENT_TRUST=1` to verify the integrity of the images.
- Bitnami container images are released on a regular basis with the latest distribution packages available.

## Why use a non-root container?

Non-root container images add an extra layer of security and are generally recommended for production environments. However, because they run as a non-root user, privileged tasks are typically off-limits. Learn more about non-root containers [in our docs](https://docs.bitnami.com/tutorials/work-with-non-root-containers/).

## Supported tags and respective `Dockerfile` links

Learn more about the Bitnami tagging policy and the difference between rolling tags and immutable tags [in our documentation page](https://docs.bitnami.com/tutorials/understand-rolling-tags-containers/).


- [`4`, `4-debian-11`, `4.2.0-6066`, `4.2.0-6066-debian-11-r6`, `latest` (4/debian-11/Dockerfile)](https://github.com/bitnami/bitnami-docker-reportserverenterprise/blob/4.2.0-6066-debian-11-r6/4/debian-11/Dockerfile)

Subscribe to project updates by watching the [bitnami/reportserverenterprise GitHub repo](https://github.com/bitnami/bitnami-docker-reportserverenterprise).

## Get this image

The recommended way to get the Bitnami ReportServer Enterprise Docker Image is to pull the prebuilt image from the [Docker Hub Registry](https://hub.docker.com/r/bitnami/reportserverenterprise).

```console
$ docker pull bitnami/reportserverenterprise:latest
```

To use a specific version, you can pull a versioned tag. You can view the [list of available versions](https://hub.docker.com/r/bitnami/reportserverenterprise/tags/) in the Docker Hub Registry.

```console
$ docker pull bitnami/reportserverenterprise:[TAG]
```

If you wish, you can also build the image yourself.

```console
$ docker build -t bitnami/reportserverenterprise:latest 'https://github.com/bitnami/bitnami-docker-reportserverenterprise.git#master:4/debian-11'
```

## How to use this image

ReportServer Enterprise requires access to a MySQL or MariaDB database to store information. We'll use the [Bitnami Docker Image for MariaDB](https://www.github.com/bitnami/bitnami-docker-mariadb) for the database requirements.

### Run the application using Docker Compose

The main folder of this repository contains a functional [`docker-compose.yml`](https://github.com/bitnami/bitnami-docker-reportserverenterprise/blob/master/docker-compose.yml) file. Run the application using it as shown below:

```console
$ curl -sSL https://raw.githubusercontent.com/bitnami/bitnami-docker-reportserverenterprise/master/docker-compose.yml > docker-compose.yml
$ docker-compose up -d
```

### Using the Docker Command Line

If you want to run the application manually instead of using `docker-compose`, these are the basic steps you need to run:

#### Step 1: Create a network

```console
$ docker network create reportserver-network
```

#### Step 2: Create a volume for MariaDB persistence and create a MariaDB container

```console
$ docker volume create --name mariadb_data
$ docker run -d --name mariadb \
  --env ALLOW_EMPTY_PASSWORD=yes \
  --env MARIADB_USER=bn_reportserver \
  --env MARIADB_PASSWORD=bitnami \
  --env MARIADB_DATABASE=bitnami_reportserver \
  --network reportserver-network \
  --volume mariadb_data:/bitnami/mariadb \
  bitnami/mariadb:latest
```

#### Step 3: Create volumes for ReportServer Enterprise persistence and launch the container

```console
$ docker volume create --name reportserver_data
$ docker run -d --name reportserver \
  -p 8080:8080 -p 8443:8443 \
  --env ALLOW_EMPTY_PASSWORD=yes \
  --env REPORTSERVER_DATABASE_USER=bn_reportserver \
  --env REPORTSERVER_DATABASE_PASSWORD=bitnami \
  --env REPORTSERVER_DATABASE_NAME=bitnami_reportserver \
  --network reportserver-network \
  --volume reportserver_data:/bitnami/reportserverenterprise \
  bitnami/reportserverenterprise:latest
```

Access your application at `http://your-ip/`

## Persisting your application

If you remove the container all your data will be lost, and the next time you run the image the database will be reinitialized. To avoid this loss of data, you should mount a volume that will persist even after the container is removed.

For persistence you should mount a directory at the `/bitnami/reportserverenterprise` path. If the mounted directory is empty, it will be initialized on the first run. Additionally you should [mount a volume for persistence of the MariaDB data](https://github.com/bitnami/bitnami-docker-mariadb#persisting-your-database).

The above examples define the Docker volumes named `mariadb_data` and `reportserver_data`. The ReportServer Enterprise application state will persist as long as volumes are not removed.

To avoid inadvertent removal of volumes, you can [mount host directories as data volumes](https://docs.docker.com/engine/tutorials/dockervolumes/). Alternatively you can make use of volume plugins to host the volume data.

### Mount host directories as data volumes with Docker Compose

This requires a minor change to the [`docker-compose.yml`](https://github.com/bitnami/bitnami-docker-reportserverenterprise/blob/master/docker-compose.yml) file present in this repository:

```diff
   mariadb:
     ...
     volumes:
-      - 'mariadb_data:/bitnami/mariadb'
+      - /path/to/mariadb-persistence:/bitnami/mariadb
   ...
   reportserver:
     ...
     volumes:
-      - 'reportserver_data:/bitnami/reportserverenterprise'
+      - /path/to/reportserver-persistence:/bitnami/reportserverenterprise
   ...
-volumes:
-  mariadb_data:
-    driver: local
-  reportserver_data:
-    driver: local
```

> NOTE: As this is a non-root container, the mounted files and directories must have the proper permissions for the UID `1001`.

### Mount host directories as data volumes using the Docker command line

#### Step 1: Create a network (if it does not exist)

```console
$ docker network create reportserver-network
```

#### Step 2. Create a MariaDB container with host volume

```console
$ docker run -d --name mariadb \
  --env ALLOW_EMPTY_PASSWORD=yes \
  --env MARIADB_USER=bn_reportserver \
  --env MARIADB_PASSWORD=bitnami \
  --env MARIADB_DATABASE=bitnami_reportserver \
  --network reportserver-network \
  --volume /path/to/mariadb-persistence:/bitnami/mariadb \
  bitnami/mariadb:latest
```

#### Step 3. Create the ReportServer Enterprise container with host volumes

```console
$ docker run -d --name reportserver \
  -p 8080:8080 -p 8443:8443 \
  --env ALLOW_EMPTY_PASSWORD=yes \
  --env REPORTSERVER_DATABASE_USER=bn_reportserver \
  --env REPORTSERVER_DATABASE_PASSWORD=bitnami \
  --env REPORTSERVER_DATABASE_NAME=bitnami_reportserver \
  --network reportserver-network \
  --volume /path/to/reportserver-persistence:/bitnami/reportserverenterprise \
  bitnami/reportserverenterprise:latest
```

## Configuration

### Environment variables

When you start the ReportServer Enterprise image, you can adjust the configuration of the instance by passing one or more environment variables either on the docker-compose file or on the `docker run` command line. If you want to add a new environment variable:

- For docker-compose add the variable name and value under the application section in the [`docker-compose.yml`](https://github.com/bitnami/bitnami-docker-reportserverenterprise/blob/master/docker-compose.yml) file present in this repository:

    ```yaml
    reportserver:
      ...
      environment:
        - REPORTSERVER_PASSWORD=my_password
      ...
    ```

- For manual execution add a `--env` option with each variable and value:

    ```console
    $ docker run -d --name reportserver -p 80:8080 -p 443:8443 \
      --env REPORTSERVER_PASSWORD=my_password \
      --network reportserver-tier \
      --volume /path/to/reportserver-persistence:/bitnami \
      bitnami/reportserverenterprise:latest
    ```

Available environment variables:

##### User and Site configuration

- `REPORTSERVER_USERNAME`: ReportServer Enterprise application username. Default: **user**
- `REPORTSERVER_PASSWORD`: ReportServer Enterprise application password. Default: **bitnami**
- `REPORTSERVER_EMAIL`: ReportServer Enterprise application email. Default: **user@example.com**
- `REPORTSERVER_FIRST_NAME`: ReportServer Enterprise first name. Default: **FirstName**
- `REPORTSERVER_LAST_NAME`: ReportServer Enterprise last name. Default: **LastName**

##### Database connection configuration

- `REPORTSERVER_DATABASE_HOST`: Hostname for the MariaDB or MySQL server. Default: **mariadb**
- `REPORTSERVER_DATABASE_PORT_NUMBER`: Port used by the MariaDB or MySQL server. Default: **3306**
- `REPORTSERVER_DATABASE_NAME`: Database name that ReportServer Enterprise will use to connect with the database. Default: **bitnami_reportserver**
- `REPORTSERVER_DATABASE_USER`: Database user that ReportServer Enterprise will use to connect with the database. Default: **bn_reportserver**
- `REPORTSERVER_DATABASE_PASSWORD`: Database password that ReportServer Enterprise will use to connect with the database. No default.
- `ALLOW_EMPTY_PASSWORD`: It can be used to allow blank passwords. Default: **no**

##### Create a database for ReportServer Enterprise using mysql-client

- `MYSQL_CLIENT_DATABASE_HOST`: Hostname for the MariaDB or MySQL server. Default: **mariadb**
- `MYSQL_CLIENT_DATABASE_PORT_NUMBER`: Port used by the MariaDB or MySQL server. Default: **3306**
- `MYSQL_CLIENT_DATABASE_ROOT_USER`: Database admin user. Default: **root**
- `MYSQL_CLIENT_DATABASE_ROOT_PASSWORD`: Database password for the database admin user. No default.
- `MYSQL_CLIENT_CREATE_DATABASE_NAME`: New database to be created by the mysql client module. No default.
- `MYSQL_CLIENT_CREATE_DATABASE_USER`: New database user to be created by the mysql client module. No default.
- `MYSQL_CLIENT_CREATE_DATABASE_PASSWORD`: Database password for the `MYSQL_CLIENT_CREATE_DATABASE_USER` user. No default.
- `MYSQL_CLIENT_CREATE_DATABASE_CHARACTER_SET`: Character set to use for the new database. No default.
- `MYSQL_CLIENT_CREATE_DATABASE_COLLATE`: Database collation to use for the new database. No default.
- `MYSQL_CLIENT_ENABLE_SSL`: Whether to enable SSL connections for the new database. Default: **no**
- `MYSQL_CLIENT_SSL_CA_FILE`: Path to the SSL CA file for the new database. No default.
- `ALLOW_EMPTY_PASSWORD`: It can be used to allow blank passwords. Default: **no**

##### SMTP Configuration

To configure ReportServer Enterprise to send email using SMTP you can set the following environment variables:

- `REPORTSERVER_SMTP_HOST`: SMTP host.
- `REPORTSERVER_SMTP_PORT`: SMTP port.
- `REPORTSERVER_SMTP_USER`: SMTP account user.
- `REPORTSERVER_SMTP_PASSWORD`: SMTP account password.
- `REPORTSERVER_SMTP_PROTOCOL`: If specified, SMTP protocol to use. Allowed values: *tls*, *ssl*. No default.

#### Examples

##### SMTP configuration using a Gmail account

This would be an example of SMTP configuration using a Gmail account:

- Modify the [`docker-compose.yml`](https://github.com/bitnami/bitnami-docker-reportserverenterprise/blob/master/docker-compose.yml) file present in this repository:

    ```yaml
      reportserver:
        ...
        environment:
          - REPORTSERVER_DATABASE_USER=bn_reportserver
          - REPORTSERVER_DATABASE_NAME=bitnami_reportserver
          - ALLOW_EMPTY_PASSWORD=yes
          - REPORTSERVER_SMTP_HOST=smtp.gmail.com
          - REPORTSERVER_SMTP_PORT=587
          - REPORTSERVER_SMTP_USER=your_email@gmail.com
          - REPORTSERVER_SMTP_PASSWORD=your_password
      ...
    ```

- For manual execution:

    ```console
    $ docker run -d --name reportserver -p 80:8080 -p 443:8443 \
      --env REPORTSERVER_DATABASE_USER=bn_reportserver \
      --env REPORTSERVER_DATABASE_NAME=bitnami_reportserver \
      --env REPORTSERVER_SMTP_HOST=smtp.gmail.com \
      --env REPORTSERVER_SMTP_PORT=587 \
      --env REPORTSERVER_SMTP_USER=your_email@gmail.com \
      --env REPORTSERVER_SMTP_PASSWORD=your_password \
      --network reportserver-tier \
      --volume /path/to/reportserver-persistence:/bitnami \
      bitnami/reportserverenterprise:latest
    ```

##### Connect ReportServer Enterprise container to an existing database

The Bitnami ReportServer Enterprise container supports connecting the ReportServer Enterprise application to an external database. This would be an example of using an external database for ReportServer Enterprise.

- Modify the [`docker-compose.yml`](https://github.com/bitnami/bitnami-docker-reportserverenterprise/blob/master/docker-compose.yml) file present in this repository:

    ```diff
       reportserver:
         ...
         environment:
    -      - REPORTSERVER_DATABASE_HOST=mariadb
    +      - REPORTSERVER_DATABASE_HOST=mariadb_host
           - REPORTSERVER_DATABASE_PORT_NUMBER=3306
           - REPORTSERVER_DATABASE_NAME=reportserver_db
           - REPORTSERVER_DATABASE_USER=reportserver_user
    -      - ALLOW_EMPTY_PASSWORD=yes
    +      - REPORTSERVER_DATABASE_PASSWORD=reportserver_password
         ...
    ```

- For manual execution:

    ```console
    $ docker run -d --name reportserver\
      -p 8080:8080 -p 8443:8443 \
      --network reportserver-network \
      --env REPORTSERVER_DATABASE_HOST=mariadb_host \
      --env REPORTSERVER_DATABASE_PORT_NUMBER=3306 \
      --env REPORTSERVER_DATABASE_NAME=reportserver_db \
      --env REPORTSERVER_DATABASE_USER=reportserver_user \
      --env REPORTSERVER_DATABASE_PASSWORD=reportserver_password \
      --volume reportserver_data:/bitnami/reportserverenterprise \
      bitnami/reportserverenterprise:latest
    ```

In case the database already contains data from a previous ReportServer Enterprise installation, you need to set the variable `REPORTSERVER_SKIP_BOOTSTRAP` to `yes`. Otherwise, the container would execute the installation wizard and could modify the existing data in the database. Note that, when setting `REPORTSERVER_SKIP_BOOTSTRAP` to `yes`, values for environment variables such as `REPORTSERVER_USERNAME`, `REPORTSERVER_PASSWORD` or `REPORTSERVER_EMAIL` will be ignored.

## Logging

The Bitnami ReportServer Enterprise Docker image sends the container logs to `stdout`. To view the logs:

```console
$ docker logs reportserver
```

Or using Docker Compose:

```console
$ docker-compose logs reportserver
```

You can configure the containers [logging driver](https://docs.docker.com/engine/admin/logging/overview/) using the `--log-driver` option if you wish to consume the container logs differently. In the default configuration docker uses the `json-file` driver.

## Maintenance

### Backing up your container

To backup your data, configuration and logs, follow these simple steps:

#### Step 1: Stop the currently running container

```console
$ docker stop reportserver
```

Or using Docker Compose:

```console
$ docker-compose stop reportserver
```

#### Step 2: Run the backup command

We need to mount two volumes in a container we will use to create the backup: a directory on your host to store the backup in, and the volumes from the container we just stopped so we can access the data.

```console
$ docker run --rm -v /path/to/reportserver-backups:/backups --volumes-from reportserver busybox \
  cp -a /bitnami/reportserverenterprise /backups/latest
```

### Restoring a backup

Restoring a backup is as simple as mounting the backup as volumes in the containers.

For the MariaDB database container:

```diff
 $ docker run -d --name mariadb \
   ...
-  --volume /path/to/mariadb-persistence:/bitnami/mariadb \
+  --volume /path/to/mariadb-backups/latest:/bitnami/mariadb \
   bitnami/mariadb:latest
```

For the ReportServer Enterprise container:

```diff
 $ docker run -d --name reportserver \
   ...
-  --volume /path/to/reportserver-persistence:/bitnami/reportserverenterprise \
+  --volume /path/to/reportserver-backups/latest:/bitnami/reportserverenterprise \
   bitnami/reportserverenterprise:latest
```

### Upgrade this image

Bitnami provides up-to-date versions of MariaDB and ReportServer Enterprise, including security patches, soon after they are made upstream. We recommend that you follow these steps to upgrade your container. We will cover here the upgrade of the ReportServer Enterprise container. For the MariaDB upgrade see: https://github.com/bitnami/bitnami-docker-mariadb/blob/master/README.md#upgrade-this-image

The `bitnami/reportserverenterprise:latest` tag always points to the most recent release. To get the most recent release you can simple repull the `latest` tag from the Docker Hub with `docker pull bitnami/reportserverenterprise:latest`. However it is recommended to use [tagged versions](https://hub.docker.com/r/bitnami/reportserverenterprise/tags/).

#### Step 1: Get the updated image

```console
$ docker pull bitnami/reportserverenterprise:latest
```

#### Step 2: Stop the running container

Stop the currently running container using the command

```console
$ docker-compose stop reportserver
```

#### Step 3: Take a snapshot of the application state

Follow the steps in [Backing up your container](#backing-up-your-container) to take a snapshot of the current application state.

#### Step 4: Remove the currently running container

Remove the currently running container by executing the following command:

```console
docker-compose rm -v reportserver
```

#### Step 5: Run the new image

Update the image tag in `docker-compose.yml` and re-create your container with the new image:

```console
$ docker-compose up -d
```

# Learn more about ReportServer Enterprise

Developers can obtain the source code for ReportServer Enterprise from [https://github.com/infofabrik/reportserver](https://github.com/infofabrik/reportserver).

Developers can also access the [API documentation](https://reportserver.net/api/current/javadoc/index.html), including information on available [entities](https://reportserver.net/api/current/entities.html), [hooks](https://reportserver.net/api/current/hooks.html) and [services](https://reportserver.net/api/current/services.html).

More information is available from the [ReportServer website](https://reportserver.net/en/).

## Notable Changes

### 3.7.0-6044-debian-10-r52

- The size of the container image has been reduced.
- The configuration logic is now based on Bash scripts in the *rootfs/* folder.

### 3.1.2-6022-debian-10-r23

- Java distribution has been migrated from AdoptOpenJDK to OpenJDK Liberica. As part of VMware, we have an agreement with Bell Software to distribute the Liberica distribution of OpenJDK. That way, we can provide support & the latest versions and security releases for Java.

## Contributing

We'd love for you to contribute to this container. You can request new features by creating an [issue](https://github.com/bitnami/bitnami-docker-reportserverenterprise/issues), or submit a [pull request](https://github.com/bitnami/bitnami-docker-reportserverenterprise/pulls) with your contribution.

## Issues

If you encountered a problem running this container, you can file an [issue](https://github.com/bitnami/bitnami-docker-reportserverenterprise/issues/new). Be sure to include the following information in your issue:

- Host OS and version
- Docker version (`docker version`)
- Output of `docker info`
- Version of this container
- The command you used to run the container, and any relevant output you saw (masking any sensitive information)

### Community supported solution

Please, note this asset is a community-supported solution. This means that the Bitnami team is not actively working on new features/improvements nor providing support through GitHub Issues. Any new issue will stay open for 20 days to allow the community to contribute, after 15 days without activity the issue will be marked as stale being closed after 5 days.

The Bitnami team will review any PR that is created, feel free to create a PR if you find any issue or want to implement a new feature.

New versions and releases cadence are not going to be affected. Once a new version is released in the upstream project, the Bitnami container image will be updated to use the latest version, supporting the different branches supported by the upstream project as usual.

## License

Copyright &copy; 2022 Bitnami

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
