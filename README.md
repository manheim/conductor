## About

This is a component for taking a request over HTTP, persisting that request, and forwarding the request onto a downstream endpoint.

One way to think about this component is that it functions similar to a proxy, but it asynchonizes the request so you don't have to wait for a response from another downstream application.

For example, let's say you had an app that let's people buy cars. When a car is bought, you send a request to the factory to make the car. You have no reason to wait for a response from the request to the factory, you only wish for the message to be delivered. However, the car factory takes a long time to process the request, or sometimes the request fails. Rather than block the app that is taking the order, you could insert an intermediate application between the two apps that will asynchronously deliver the message. The intermediate app stores the message and immediately returns a "200" HTTP response and delivers the message for you later.

Now, there is an added wrinkle. The car buying app let's people continue to do other things like add accessories onto the car, or remove them. Those changes are also delivered as messages to the factory, but you'd want to be sure that each change is delivered in order so that the car the factory produces is correct. You can't just send every message sequentially because so many cars are being purchased that it would never send all the messages. So, you need to split the messages into groups that have to sent sequentially, but allow groups to be sent in parallel with other groups.

**Enter the Conductor App!**

The conductor app stores an http request and a shard identifier (from header) that tells it what group the message belongs to. Examples of a good shard id could be the user buying the car, or perhaps some kind of vehicle identification number from the car buying app.

Then the conductor app uses a pool of workers to send out messages in parallel, but keeps them sequential within a group.

## Building

The conductor app comes with dockerfiles that build docker images for the various components:

* Dockerfile - The web process that receives messages
* DockerfileCleaner - The "Cleanup" worker that deletes old messages
* DockerfileMonitoring - The workers that send out alerts if the conductor is unhealthy
* DockerfileWorker - The multithreaded worker process for sending out the messages later

## Usage

### Running:
**Run using Foreman**
```
bundle install
foreman start
```
You can then submit messages via http://localhost:3000/messages  
*Monitoring is turned off by default. Uncomment to activate.*

**Run using Docker-compose**  
Coming Soon

**Run yourself**
```
bundle exec puma config.ru -p 3000
bundle exec rake workers:start
bundle exec rake database_cleaner:start
bundle exec rake monitoring:start
```

**Run on Elastic Beanstalk**  

Example `Dockerrun.json` file for running application in containers on Elastic Beanstalk
```
{
    "AWSEBDockerrunVersion": 2,
    "containerDefinitions": [
        {
            "name": "conductor",
            "image": "image:BUILD_NUMBER",
            "essential": true,
            "portMappings": [
                {
                  "hostPort": 80,
                  "containerPort": 8080
                }
            ],
            "memoryReservation": 512
        },
        {
            "name": "conductor_cleaner",
            "image": "image:BUILD_NUMBER",
            "essential": true,
            "memoryReservation": 128
        },
        {
            "name": "conductor_worker",
            "image": "image:BUILD_NUMBER",
            "essential": true,
            "memoryReservation": 512
        },
        {
            "name": "conductor_monitoring",
            "image": "image:BUILD_NUMBER",
            "essential": true,
            "memoryReservation": 128
        }
    ],
    "volumes": [
        {
            "name": "docker-socket",
            "host": {
                       "sourcePath": "/var/run/docker.sock"
             }
        }
    ]
}
```

**Deployment Tips**

On newer platforms the glibc library has changed to allocate more memory in multi-threaded applications such as the conductor (in order to make memory allocation faster).

If you'd like to reduce the memory footprint so that you can run on a smaller instance with less memory, you may want to set MALLOC_ARENA_MAX as an environment variable

See these references for more information:

<https://devcenter.heroku.com/articles/tuning-glibc-memory-behavior#when-to-tune-malloc_arena_max>

<https://www.gnu.org/software/libc/manual/html_node/Memory-Allocation-Tunables.html>

**Admin Tool**
 - Available under the path /admin
 - Is username and password protected
 - Provides read-only and admin access
 - Allows users to message history
 - Shows details of each message such as: Datetime received, whether it's been sent, errors encountered while sending, etc
 - Health section outlines details of conduct system's health such as: number of blocked shards, "queue depth", throughput, etc

**Sending messages in to conductor**
 - Send message to /messages via HTTP POST
 - Include in POST headers the shard identifier for the message (see config)
 - The conductor application will send the message to the configured target endpoint (see config)

## API

There is a json api in the conductor that you can use to search for messages.

### Search

*Requires at least guest level credentials*

Here is an example request that returns the first 25 message id:

```
curl -H "Authorization: Basic YWRtaW46cGFzc3dvcmQ=" \
     "http://localhost:3000/messages/search"
```

Example response:

```
{"items":[{"id":4},{"id":5},{"id":6},{"id":7},{"id":8},{"id":9},{"id":10},{"id":11},{"id":12},{"id":13},{"id":14},{"id":15},{"id":16},{"id":17},{"id":18},{"id":19},{"id":20},{"id":21},{"id":22},{"id":23},{"id":24},{"id":25},{"id":26},{"id":27},{"id":28}]}
```

There are a set of query parameters you can provide while searching:

* limit - Max number of records to return
* start - A message id to use as the start of the search (not inclusive). This parameter makes it possible to fetch the next page by using the last id of the previous page.
* created_before - A date or datetime to use to search for messages older that the time
* created_after - A date or datetime to use to search for messages newer that the time
* text - A value that can be matched against the configured search texts for messages

### Show

*Requires at least guest level credentials*

Example request:

```
curl -H "Authorization: Basic YWRtaW46cGFzc3dvcmQ=" \
     "http://localhost:3000/messages/7"
```

Example response:

```
{
  "id": 7,
  "shard_id": null,
  "body": "Some Body",
  "headers": "{\"Version\":\"HTTP/1.1\",\"User-agent\":\"Faraday v0.9.2\",\"Correlationid\":\"\",\"Event-conductor-shard-id\":\"ht    tp://localhost:9000/units/id/def0f676-9aef-11e6-8e2d-4f90900f926d\",\"Conductor-enabled-tag\":\"true\",\"Authorization\":\"Bearer pvt8b8s5u9xzp64re5c4m    qrz\",\"Accept-encoding\":\"gzip;q=1.0,deflate;q=0.6,identity;q=0.3\",\"Accept\":\"*/*\",\"Connection\":\"close\",\"Content-type\":\"application/json\"    ,\"X-Forwarded-Host\":\"localhost\",\"X-Forwarded-Port\":\"3000\",\"X-Forwarded-For\":\"127.0.0.1\"}",
  "succeeded_at": null,
  "processed_at": null,
  "processed_count": 0,
  "last_failed_at": null,
  "last_failed_message": null,
  "response_code": null,
  "response_body": null,
  "needs_sending": true,
  "created_at": "2016-10-25T20:16:11.252Z",
  "updated_at": "2016-10-25T20:16:11.252Z"
}
```

### Single Update

*Requires Admin level credentials*  
*Currently only the `needs_sending` flag can be updated*

Example request:

```
curl -v -X POST -H "Content-Type: application/json" \
     -H "Authorization: Basic YWRtaW46cGFzc3dvcmQ=" \
     "http://localhost:3000/messages/7" \
     -d '{"needs_sending": false}'
```

Possible HTTP Response codes:

* 204 if the message was successfully updated
* 404 if the message was not found
* 401 if the basic auth credentials are incorrect or do not have permission
* 400 if no data was provided to update

*HTTP Response code of 4xx indicates the Message has not been updated*

### Bulk Update

*Requires Admin level credentials*  
*Currently only the `needs_sending` flag can be updated*

This allows for multiple messages to be updated given their id.

All updates are done as one transaction so there will never be a partial update if an error occurs.

Example request:

```
curl -v -X POST -H "Content-Type: application/json" \
     -H "Authorization: Basic YWRtaW46cGFzc3dvcmQ=" \
     "http://localhost:3000/messages/bulk_update" \
     -d '{"items": [7, 8], "data": {"needs_sending": false}}'
```

Possible HTTP Response codes:

* 204 if the messages was successfully updated
* 401 if the basic auth credentials are incorrect or do not have permission
* 400 if no data was provided to update
* 400 if too many ids were provided
* 400 if some ids don't exist

*HTTP Response code of 4xx indicates no Messages have been updated*


## Configuration

Configuration is done via Environmental Variables.

**Highlighted Config Options**  
Where are messages sent? - See `ENDPOINT_HOSTNAME`, `ENDPOINT_PATH`, `ENDPOINT_QUERY`  
Where do logs go? - Loggly, see `LOG_PATH`
What is the shard identifier in the POST header? - see `CONDUCTOR_SHARD_TAG`  
What is the login to the admin page? - see `BASIC_AUTH_ENABLED`, `BASIC_AUTH_USER`, `BASIC_AUTH_PASSWORD` and hardcoded  
How does conductor know if a message it receives should be sent? - see `CONDUCTOR_ENABLE_TAG` and `WORKERS_ENABLED`

**All Available Environmental Variables**

`APP_ENV` - The environment that app is running in. Ex: ci, uat, production  
`TEAM_NAME` - The name of the team you are on. This is used to send metrics to DataDog. If it is not set metrics are not pushed.  
`ASSOCIATED_APPLICATION_NAME` - The name of the application you are pairing with conductor. This is used to send metrics to DataDog. If it is not set metrics are not pushed.  
`BASIC_AUTH_ENABLED` - Should we require authenthentication of admin pages  
`BASIC_AUTH_USER` - Admin username  
`BASIC_AUTH_PASSWORD` - Admin password  
`RETENTION_PERIOD_SECONDS` - Number of seconds we should keep a sent message around  
`CLEANUP_CRON_JOB_SCHEDULE` - Schedule for cleanup sweeps  
`MONITORING_CRON_JOB_SCHEDULE` - Schedule for alerting sweeps  
`DELETION_BATCH_SIZE` - How many messages are deleted from the database each cleaner sweep  
`AUTOGENERATE_SHARD_ID` - Set to 'true' if you would like to randomly shard out messages  
`AUTOGENERATE_SHARD_ID_RANGE` - When autogenerating shards, specify this for the max number of shards  
`CONDUCTOR_SHARD_TAG` - HTTP header which will define the shard id for a POST'd message  
`EXTRACT_SHARD_ENABLED` - Autoextract the message's shard id from it's body. Defaults to: `false`  
`EXTRACT_SHARD_CONTENT_TYPE` - Content type of message bodies. Ex: `json` or `xml` 
`EXTRACT_SHARD_PATH` - Path to value within message's body which will be used as the message's shard id. Ex: `body.href` or an xpath expression for xml 
`CONDUCTOR_ENABLE_TAG` - HTTP header which message will have to have included for the message to be considered 'to-be-sent'  
`ENDPOINT_PATH` - Path of URL for POSTing to message receiver  
`ENDPOINT_QUERY` - Query params of URL for POSTing to message receiver  
`WORKERS_ENABLED` - Enable message sending workers. Will not send messages if not set  
`THREADED_WORKER_THREAD_COUNT` - Worker pool size. Defaults to: `10`  
`THREADED_WORKER_SLEEP_DELAY` - Number of seconds to sleep the worker between polling for unsent messages. Defaults to: `1`  
`THREADED_WORKER_NO_WORK_DELAY` - Number of seconds to sleep a worker if there are no unsend messages. Defaults to: `1`  
`THREADED_WORKER_FAILURE_DELAY` - Number of seconds to sleep a shard if message delivery fails. Defaults to: `35`  
`UNHEALTHY_SHARD_THRESHOLD` - Count of how many data shards must be blocked for the system to be considered unhealthy  
`UNHEALTHY_MESSAGE_AGE_IN_SECONDS` - Age in seconds of oldest message until the system is considered unhealthy  
`BLOCKED_SHARD_MESSAGE_FAILURE_THRESHOLD` - Number of times a message must be retried before it is considered to be blocking a shard  
`UNSENT_MESSAGE_COUNT_THRESHOLD` - Number of unsent messages system should have to be considered unhealthy  
`UNDELIVERABLE_PERCENT_HEALTH_THRESHOLD` - Percent of messages in last 10 minutes which were not able to be delivered. Only works if messages can become undeliverable due to MAX_NUMBER_OF_RETRIES  
`CONDUCTOR_HEALTH_PAGE_URL` - Full URL to application's health page. Is included in PagerDuty alert  
`PAGERDUTY_SERVICE_KEY` - API Key for PagerDuty  
`DATADOG_API_KEY` - The API key you would like to use to push metrics to data dog. If not present metrics are not pushed.  
`NEW_RELIC_APP_NAME` - Application Name for reporting to newrelic  
`LOG_PATH` - A file path to write the logs to. Defaults to standard out if not set
`MAX_NUMBER_OF_RETRIES` - Number of attempts to send message before giving up  
`MOST_EXPECTED_MINUTES_BETWEEN_MESSAGES` - How long should conductor wait before alerting about starvation
`INBOUND_MESSAGE_FILTER` - A JMESPath expression for whitelisting/allowing certain messages based on content. Only works for json messages.

Hardcoded:
 - readonly_username = 'guest' # credentials for read-only view of admin pages
 - readonly_password = 'readonly'
 - runtime_settings_cache_expiration_seconds = 60


**Runtime Settings**

There is the ability to change some settings at runtime. The settings will be persisted in the database.

Currently there is one updateable setting that allows you to pause the workers.

`workers_enabled` - Set to false to effectively "pause" outbound message sending

An example POST request:

```
curl -H 'Content-Type: application/json' \
     -H "Authorization: Basic YWRtaW46cGFzc3dvcmQ=" \
     -X POST \
     -d '{"settings":{ "workers_enabled": false }}' \
     http://localhost:3000/runtime_settings
```

An example GET request:


```
curl http://localhost:3000/runtime_settings
```
