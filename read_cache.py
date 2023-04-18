import time
import re
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import httpx
from cache_util import CacheUtil, GITHUB_API_BASE_URL, auth_headers
import heapq
import threading

app = FastAPI()
cache_util = CacheUtil()

cache: {} = None
timer: threading.Timer

# Define an allow list for API endpoints
ALLOWED_ENDPOINTS = [
    "/",
    "/orgs/Netflix",
    "/orgs/Netflix/members",
    "/orgs/Netflix/repos",
    "/healthcheck",
]

ALLOWED_PATTERN_FORKS = r"^/view/bottom/(?P<n>\d+)/forks$"
ALLOWED_PATTERN_LAST_UPDATED = r"^/view/bottom/(?P<n>\d+)/last_updated$"
ALLOWED_PATTERN_OPEN_ISSUES = r"^/view/bottom/(?P<n>\d+)/open_issues$"
ALLOWED_PATTERN_STARS = r"^/view/bottom/(?P<n>\d+)/stars$"


def recreate_cache():
    # print("start cache")
    cache["/"] = cache_util.get_all_results("", 100)
    cache["/orgs/Netflix"] = cache_util.get_all_results("orgs/Netflix", 100)
    cache["/orgs/Netflix/repos"] = cache_util.get_all_results("orgs/Netflix/repos", 100)
    cache["/orgs/Netflix/members"] = cache_util.get_all_results("orgs/Netflix/members", 100)
    cache["netflix_result"] = cache_util.get_from_netflix_repos(cache["/orgs/Netflix/repos"])
    # print("end cache")

    global timer
    timer = threading.Timer(10.0, recreate_cache)
    timer.start()


@app.on_event("startup")
async def on_startup():
    global cache
    cache = {}
    recreate_cache()


@app.on_event("shutdown")
def shutdown_event():
    if not timer:
        timer.cancel()


@app.middleware("http")
async def proxy_disallowed_requests(request: Request, call_next):
    match_pattern = False
    for pattern in [ALLOWED_PATTERN_FORKS, ALLOWED_PATTERN_LAST_UPDATED, ALLOWED_PATTERN_OPEN_ISSUES,
                    ALLOWED_PATTERN_STARS]:
        if re.match(pattern, request.url.path):
            match_pattern = True

    # Check if the request path is in the allowed endpoints list
    if request.url.path not in ALLOWED_ENDPOINTS and not match_pattern:
        # If it's not, proxy the request through the service to GitHub
        async with httpx.AsyncClient() as client:
            github_url = f"{GITHUB_API_BASE_URL}{request.url.path}"
            response = await client.request(request.method, github_url, headers=auth_headers, data=request.stream())
        return JSONResponse(content=response.json(), status_code=response.status_code)
    else:
        # If it is, allow the request to proceed as normal
        response = await call_next(request)
        return response


# Implement the cached routes for path "/"
@app.get("/")
async def get_root():
    return cache["/"]


# Implement the cached routes for path "/orgs/Netflix"
@app.get("/orgs/Netflix")
async def get_netflix():
    return cache["/orgs/Netflix"]


# Implement the cached routes for path "/orgs/Netflix/members"
@app.get("/orgs/Netflix/members")
async def get_netflix_members():
    return cache["/orgs/Netflix/members"]


# Implement the cached routes for path "/orgs/Netflix/repos"
@app.get("/orgs/Netflix/repos")
async def get_netflix_repos():
    return cache["/orgs/Netflix/repos"]


@app.get("/view/bottom/{n}/forks")
async def get_bottom_n_forks(n: int):
    return [[x[1], -x[0]] for x in heapq.nlargest(n, cache["netflix_result"]["forks"])][::-1]


@app.get('/view/bottom/{n}/last_updated')
async def get_bottom_n_last_updated(n: int):
    return [[x[1], x[2]] for x in heapq.nlargest(n, cache["netflix_result"]["last_updated"])][::-1]


@app.get("/view/bottom/{n}/open_issues")
async def get_bottom_n_open_issues(n: int):
    return [[x[1], -x[0]] for x in heapq.nlargest(n, cache["netflix_result"]["open_issues"])][::-1]


@app.get("/view/bottom/{n}/stars")
async def get_bottom_n_forks(n: int):
    return [[x[1], -x[0]] for x in heapq.nlargest(n, cache["netflix_result"]["stars"])][::-1]


@app.get("/healthcheck")
async def health_check():
    while not cache or "netflix_result" not in cache:
        time.sleep(1)
    return '', 200
