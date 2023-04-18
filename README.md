# API Caching Service

## Introduction

This is a caching service for the GitHub API. It periodically caches the results of API calls for certain endpoints for faster access and performance. It also allows access to following specific API endpoints, while proxying all other requests to the actual GitHub API.


### Endpoints
| Endpoints                              | Return Value                |
| ----------------------------- | ------------------------------------------------------------------------- |
| /                             | Returns the cached payloads for the root endpoint.                |
| /orgs/Netflix                 | Returns the cached payloads for the orgs/Netflix endpoint.                   |
| /orgs/Netflix/members         | Returns the cached payloads for the orgs/Netflix/members endpoint.   |
| /orgs/Netflix/repos           | Returns the cached payloads for the orgs/Netflix/repos endpoint.|
| /view/bottom/{n}/forks        | Returns Bottom-N repos by number of forks.              |
| /view/bottom/{n}/last_updated | Returns Bottom-N repos by last updated time.              |
| /view/bottom/{n}/open_issues  | Returns Bottom-N repos by open issues.        |
| /view/bottom/{n}/stars        | Returns Bottom-N repos by stars.              |
| /healthcheck.                 | Returns a 200 status code if the caching service is up and running.        | 

## Design Details

This is a FastAPI-based service that acts as a caching layer for the GitHub API. It caches the results of several GitHub API endpoints, such as /orgs/Netflix, /orgs/Netflix/repos, and /orgs/Netflix/members, as well as some custom endpoints that compute statistics on the Netflix repositories. Requests to these endpoints are served from the cache, while requests to other endpoints are proxied through the service to the GitHub API. 

The cache is recreated every 10 seconds in a separate thread, and a health check endpoint (/healthcheck) is provided to ensure that the cache has been initialized before serving requests. Overall, the service provides a faster and more efficient way to retrieve information from the GitHub API by minimizing the number of requests made to the API and caching frequently accessed data.


### Web Service : why FastAPI?

It provides a web framework for building the REST api. I also leveraged the middleware feature to proxy the requests outside of the above endpoints.


### Cache Update Mechanism:
 All the end point accessable data will be  periodically(10s) refreshed in cache


### Custom views logic: 
Use heap sort to generate bottom-n data and store it in cache

# Technologies Used
* Python
* FastAPI
* Requests
* Httpx

# Run

## Preparation 

```
git clone https://github.com/zigeH/api_read_cache.git
cd api_read_cache
```

It requires to install the uvicorn[https://www.uvicorn.org/], curl, jq tool. 
```
pip install uvicorn 
brew install jq  
```
Paste your own token into the cache_util.py
```
GITHUB_API_TOKEN = “YOUR_API_TOKEN”
```

Terminal 1:
You can provide your own port number
```
uvicorn read_cache:app --port [YOUR_OWN_PORT_NUMBER] --reload
```

Terminal 2: 
/bin/bash api-suite.sh

## Test result

All the test cases should be coverd by the provided code. The test cases are not fully passed because of the data drift. 

With the provided test cases, I got 13/30 (43.00%) tests passed. However, I have checked all the test case manually, all the outputs are correct and expected.

For example, current active members is 29 as listed on the website. However, test-04-01 failed because the expected result is between 16 .. 20
```
 /orgs/Netflix/members object count = failed 
  expected=16..20 
  response=29 
```








