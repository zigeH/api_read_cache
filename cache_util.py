import requests
import heapq
import datetime

# GitHub API base URL
GITHUB_API_BASE_URL = "https://api.github.com"

# GitHub API token
GITHUB_API_TOKEN = "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"

auth_headers = {"Authorization": f"Bearer {GITHUB_API_TOKEN}"}


class CacheUtil:

    # Aggregate all paginated info from GitHub
    def get_all_results(self, url, per_page):
        url = f"{GITHUB_API_BASE_URL}/{url}?simple=yes&per_page={per_page}&page=1"
        res = requests.get(url, headers=auth_headers)
        repos = res.json()
        while "next" in res.links.keys():
            res = requests.get(res.links["next"]["url"], headers=auth_headers)
            repos.extend(res.json())
        return self.flatten_response(repos)

    # Flatten list of json response
    def flatten_response(self, json_obj, prefix=""):
        if isinstance(json_obj, list):
            # flatten list of objects
            return [self.flatten_json(item, prefix) for item in json_obj]
        else:
            # flatten a single objects
            return self.flatten_json(json_obj, prefix)

    # Flatten a single json object
    def flatten_json(self, json_obj, prefix=""):
        flat_dict = {}
        for key, value in json_obj.items():
            new_key = prefix + key
            if isinstance(value, dict):
                flat_dict.update(self.flatten_json(value, new_key + "."))
            else:
                flat_dict[new_key] = value
        return flat_dict

    # Generate custom views based on Netflix repos info.
    def get_from_netflix_repos(self, repos):
        result = {}
        forks = []
        last_updated = []
        open_issues = []
        stars = []

        for repo in repos:
            if "forks" in repo:
                forks_count = -repo["forks"]
                heapq.heappush(forks, (forks_count, repo["full_name"]))

            if "updated_at" in repo:
                updated_time_in_ms = -datetime.datetime.strptime(repo["updated_at"], "%Y-%m-%dT%H:%M:%SZ").timestamp()
                heapq.heappush(last_updated, (updated_time_in_ms, repo["full_name"], repo["updated_at"]))

            if "open_issues" in repo:
                open_issues_count = -repo["open_issues"]
                heapq.heappush(open_issues, (open_issues_count, repo["full_name"]))

            if "stargazers_count" in repo:
                stars_count = -repo["stargazers_count"]
                heapq.heappush(stars, (stars_count, repo["full_name"]))

        result.setdefault("forks", forks)
        result.setdefault("last_updated", last_updated)
        result.setdefault("open_issues", open_issues)
        result.setdefault("stars", stars)

        return result
