#!/bin/bash

APP_PORT=${1:-8080}
HEALTHCHECK_PORT=${2:-$APP_PORT}
BASE_URL="http://localhost:$APP_PORT"
HEALTHCHECK_URL="http://localhost:$HEALTHCHECK_PORT"

for TOOL in bc curl jq wc awk sort uniq tr head tail; do
    if ! which $TOOL >/dev/null; then
        echo "ERROR: $TOOL is not available in the PATH"
        exit 1
    fi
done

PASS=0
FAIL=0
TOTAL=0

function describe() {
    echo -n "$1"
    let TOTAL=$TOTAL+1
}

function pass() {
    echo "pass"
    let PASS=$PASS+1
}

function fail() {
    RESPONSE=$1
    EXPECTED=$2
    echo "failed"
    echo "  expected=$EXPECTED"
    echo "  response=$RESPONSE"
    let FAIL=$FAIL+1
}

function report() {
    PCT=$(echo "scale=2; $PASS / $TOTAL * 100" |bc)
    echo "$PASS/$TOTAL ($PCT%) tests passed"
}

describe "test-01-01: healthcheck = "

ATTEMPTS=0
while true; do
    let ATTEMPTS=$ATTEMPTS+1
    RESPONSE=$(curl -s -o /dev/null -w '%{http_code}' "$HEALTHCHECK_URL/healthcheck")
    if [[ $RESPONSE == "200" ]]; then
        let TIME=$ATTEMPTS*15
        echo -n "($TIME seconds) "; pass
        break
    else
        if [[ $ATTEMPTS -gt 24 ]]; then
            let TIME=$ATTEMPTS*15
            echo -n "($TIME seconds) "; fail
            break
        fi
        sleep 15
    fi
done

describe "test-02-01: / key count = "

COUNT=$(curl -s "$BASE_URL" |jq -r 'keys |.[]' |wc -l |awk '{print $1}')

if [[ $COUNT -eq 32 ]]; then
    pass
else
    fail "$COUNT" "32"
fi

describe "test-02-02: / repository_search_url value = "

VALUE=$(curl -s "$BASE_URL" |jq -r '.repository_search_url')

if [[ "$VALUE" == "https://api.github.com/search/repositories?q={query}{&page,per_page,sort,order}" ]]; then
    pass
else
    fail "$VALUE" "https://api.github.com/search/repositories?q={query}{&page,per_page,sort,order}"
fi

describe "test-02-03: / organization_repositories_url value = "

VALUE=$(curl -s "$BASE_URL" |jq -r '.organization_repositories_url')

if [[ "$VALUE" == "https://api.github.com/orgs/{org}/repos{?type,page,per_page,sort}" ]]; then
    pass
else
    fail "$VALUE" "https://api.github.com/orgs/{org}/repos{?type,page,per_page,sort}"
fi

describe "test-03-01: /orgs/Netflix key count = "

COUNT=$(curl -s "$BASE_URL/orgs/Netflix" |jq -r 'keys |.[]' |wc -l |awk '{print $1}')

if [[ $COUNT -eq 29 ]]; then
    pass
else
    fail "$COUNT" "29"
fi

describe "test-03-02: /orgs/Netflix avatar_url = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix" |jq -r '.avatar_url')

if [[ "$VALUE" == "https://avatars.githubusercontent.com/u/913567?v=4" ]]; then
    pass
else
    fail "$VALUE" "https://avatars.githubusercontent.com/u/913567?v=4"
fi

describe "test-03-03: /orgs/Netflix location = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix" |jq -r '.location')

if [[ "$VALUE" == "Los Gatos, California" ]]; then
    pass
else
    fail "$VALUE" "Los Gatos, California"
fi

describe "test-04-01: /orgs/Netflix/members object count = "

COUNT=$(curl -s "$BASE_URL/orgs/Netflix/members" |jq -r '. |length')

if [[ $COUNT -gt 16 ]] && [[ $COUNT -lt 20 ]]; then
    pass
else
    fail "$COUNT" "16..20"
fi

describe "test-04-02: /orgs/Netflix/members login first alpha case-insensitive = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix/members" |jq -r '.[] |.login' |tr '[:upper:]' '[:lower:]' |sort |head -1)

if [[ "$VALUE" == "antonio-osorio" ]]; then
    pass
else
    fail "$VALUE" "antonio-osorio"
fi

describe "test-04-03: /orgs/Netflix/members login first alpha case-sensitive = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix/members" |jq -r '.[] |.login' |sort |head -1)

if [[ "$VALUE" == "antonio-osorio" ]]; then
    pass
else
    fail "$VALUE" "antonio-osorio"
fi

describe "test-04-04: /orgs/Netflix/members login last alpha case-insensitive = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix/members" |jq -r '.[] |.login' |tr '[:upper:]' '[:lower:]' |sort |tail -1)

if [[ "$VALUE" == "wesleytodd" ]]; then
    pass
else
    fail "$VALUE" "wesleytodd"
fi

describe "test-04-05: /orgs/Netflix/members id first = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix/members" |jq -r '.[] |.id' |sort -n |head -1)

if [[ "$VALUE" == "132086" ]]; then
    pass
else
    fail "$VALUE" "132086"
fi

describe "test-04-06: /orgs/Netflix/members id last = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix/members" |jq -r '.[] |.id' |sort -n |tail -1)

if [[ "$VALUE" == "8943572" ]]; then
    pass
else
    fail "$VALUE" "8943572"
fi

describe "test-04-07: /users/antonio-osorio/orgs proxy = "

VALUE=$(curl -s "$BASE_URL/users/antonio-osorio/orgs" |jq -r '.[] |.login' |tr '\n' ':')

if [[ "$VALUE" == "Netflix:" ]]; then
    pass
else
    fail "$VALUE" "Netflix:"
fi

describe "test-04-08: /users/wesleytodd/orgs proxy = "

VALUE=$(curl -s "$BASE_URL/users/wesleytodd/orgs" |jq -r '.[] |.login' |tr '\n' ':')

if [[ "$VALUE" == "Netflix:expressjs:restify:Node-Ops:jshttp:pillarjs:nodejs:MusicMapIo:migratejs:pkgjs:" ]]; then
    pass
else
    fail "$VALUE" "Netflix:expressjs:restify:Node-Ops:jshttp:pillarjs:nodejs:MusicMapIo:migratejs:pkgjs:"
fi

describe "test-05-01: /orgs/Netflix/repos object count = "

COUNT=$(curl -s "$BASE_URL/orgs/Netflix/repos" |jq -r '. |length')

if [[ $COUNT -gt 177 ]] && [[ $COUNT -lt 227 ]]; then
    pass
else
    fail "$COUNT" "177..227"
fi

describe "test-05-02: /orgs/Netflix/repos full_name first alpha case-insensitive = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix/repos" |jq -r '.[] |.full_name' |tr '[:upper:]' '[:lower:]' |sort |head -1)

if [[ "$VALUE" == "netflix/.github" ]]; then
    pass
else
    fail "$VALUE" "netflix/.github"
fi

describe "test-05-03: /orgs/Netflix/members full_name first alpha case-sensitive = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix/members" |jq -r '.[] |.full_name' |sort |head -1)

if [[ "$VALUE" == "null" ]]; then
    pass
else
    fail "$VALUE" "null"
fi

describe "test-05-04: /orgs/Netflix/members login last alpha case-insensitive = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix/members" |jq -r '.[] |.full_name' |tr '[:upper:]' '[:lower:]' |sort |tail -1)

if [[ "$VALUE" == "null" ]]; then
    pass
else
    fail "$VALUE" "null"
fi

describe "test-05-05: /orgs/Netflix/repos id first = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix/repos" |jq -r '.[] |.id' |sort -n |head -1)

if [[ "$VALUE" == "2044029" ]]; then
    pass
else
    fail "$VALUE" "2044029"
fi

describe "test-05-06: /orgs/Netflix/repos id last = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix/repos" |jq -r '.[] |.id' |sort -n |tail -1)

if [[ "$VALUE" == "378240844" ]]; then
    pass
else
    fail "$VALUE" "378240844"
fi

describe "test-05-07: /orgs/Netflix/repos languages unique = "

VALUE=$(curl -s "$BASE_URL/orgs/Netflix/repos" |jq -r '.[] |.language' |sort -u |tr '\n' ':')

if [[ "$VALUE" == "C:C#:C++:Clojure:D:Dockerfile:Go:Groovy:HCL:HTML:Java:JavaScript:Kotlin:Python:R:Ruby:Scala:Shell:TypeScript:Vue:null:" ]]; then
    pass
else
    fail "$VALUE" "C:C#:C++:Clojure:D:Dockerfile:Go:Groovy:HCL:HTML:Java:JavaScript:Kotlin:Python:R:Ruby:Scala:Shell:TypeScript:Vue:null:"
fi

describe "test-06-01: /view/bottom/5/forks = "

VALUE=$(curl -s "$BASE_URL/view/bottom/5/forks" |tr -d '\n' |sed -e 's/ //g')

if [[ "$VALUE" == '[["Netflix/dgs-examples-java16",1],["Netflix/read_bbrlog",1],["Netflix/dgs-examples-webflux",0],["Netflix/eclipse-jifa",0],["Netflix/eclipse-mat",0]]' ]]; then
    pass
else
    fail "$VALUE" '[["Netflix/dgs-examples-java16",1],["Netflix/read_bbrlog",1],["Netflix/dgs-examples-webflux",0],["Netflix/eclipse-jifa",0],["Netflix/eclipse-mat",0]]'
fi

describe "test-06-02: /view/bottom/10/forks = "

VALUE=$(curl -s "$BASE_URL/view/bottom/10/forks" |tr -d '\n' |sed -e 's/ //g')

if [[ "$VALUE" == '[["Netflix/tcplog_dumper",2],["Netflix/titus-kube-common",2],["Netflix/titus-resource-pool",2],["Netflix/vmaf_resource",2],["Netflix/.github",1],["Netflix/dgs-examples-java16",1],["Netflix/read_bbrlog",1],["Netflix/dgs-examples-webflux",0],["Netflix/eclipse-jifa",0],["Netflix/eclipse-mat",0]]' ]]; then
    pass
else
    fail "$VALUE" '[["Netflix/tcplog_dumper",2],["Netflix/titus-kube-common",2],["Netflix/titus-resource-pool",2],["Netflix/vmaf_resource",2],["Netflix/.github",1],["Netflix/dgs-examples-java16",1],["Netflix/read_bbrlog",1],["Netflix/dgs-examples-webflux",0],["Netflix/eclipse-jifa",0],["Netflix/eclipse-mat",0]]'
fi

describe "test-06-03: /view/bottom/5/last_updated = "

VALUE=$(curl -s "$BASE_URL/view/bottom/5/last_updated" |tr -d '\n' |sed -e 's/ //g')

if [[ "$VALUE" == '[["Netflix/vizceral-react","2021-07-21T09:15:11Z"],["Netflix/Workflowable","2021-07-18T01:19:49Z"],["Netflix/yetch","2021-05-13T00:46:26Z"],["Netflix/metrics-client-go","2021-04-21T02:33:56Z"],["Netflix/sleepy-puppy-docker","2021-04-21T02:33:56Z"]]' ]]; then
    pass
else
    fail "$VALUE" '[["Netflix/vizceral-react","2021-07-21T09:15:11Z"],["Netflix/Workflowable","2021-07-18T01:19:49Z"],["Netflix/yetch","2021-05-13T00:46:26Z"],["Netflix/metrics-client-go","2021-04-21T02:33:56Z"],["Netflix/sleepy-puppy-docker","2021-04-21T02:33:56Z"]]'
fi

describe "test-06-04: /view/bottom/10/last_updated = "

VALUE=$(curl -s "$BASE_URL/view/bottom/10/last_updated" |tr -d '\n' |sed -e 's/ //g')

if [[ "$VALUE" == '[["Netflix/spectator","2021-08-10T19:05:23Z"],["Netflix/metaflow-docs","2021-08-10T19:04:20Z"],["Netflix/pollyjs","2021-08-09T04:21:55Z"],["Netflix/titus-control-plane","2021-08-06T15:41:12Z"],["Netflix/Fido","2021-07-27T02:53:40Z"],["Netflix/vizceral-react","2021-07-21T09:15:11Z"],["Netflix/Workflowable","2021-07-18T01:19:49Z"],["Netflix/yetch","2021-05-13T00:46:26Z"],["Netflix/metrics-client-go","2021-04-21T02:33:56Z"],["Netflix/sleepy-puppy-docker","2021-04-21T02:33:56Z"]]' ]]; then
    pass
else
    fail "$VALUE" '[["Netflix/spectator","2021-08-10T19:05:23Z"],["Netflix/metaflow-docs","2021-08-10T19:04:20Z"],["Netflix/pollyjs","2021-08-09T04:21:55Z"],["Netflix/titus-control-plane","2021-08-06T15:41:12Z"],["Netflix/Fido","2021-07-27T02:53:40Z"],["Netflix/vizceral-react","2021-07-21T09:15:11Z"],["Netflix/Workflowable","2021-07-18T01:19:49Z"],["Netflix/yetch","2021-05-13T00:46:26Z"],["Netflix/metrics-client-go","2021-04-21T02:33:56Z"],["Netflix/sleepy-puppy-docker","2021-04-21T02:33:56Z"]]'
fi

describe "test-06-05: /view/bottom/5/open_issues = "

VALUE=$(curl -s "$BASE_URL/view/bottom/5/open_issues" |tr -d '\n' |sed -e 's/ //g')

if [[ "$VALUE" == '[["Netflix/titus-controllers-api",0],["Netflix/titus-resource-pool",0],["Netflix/tslint-config-netflix",0],["Netflix/user2020-metaflow-tutorial",0],["Netflix/webpack-parse-query",0]]' ]]; then
    pass
else
    fail "$VALUE" '[["Netflix/titus-controllers-api",0],["Netflix/titus-resource-pool",0],["Netflix/tslint-config-netflix",0],["Netflix/user2020-metaflow-tutorial",0],["Netflix/webpack-parse-query",0]]'
fi

describe "test-06-06: /view/bottom/10/open_issues = "

VALUE=$(curl -s "$BASE_URL/view/bottom/10/open_issues" |tr -d '\n' |sed -e 's/ //g')

if [[ "$VALUE" == '[["Netflix/signal-wrapper",0],["Netflix/spectator-cpp",0],["Netflix/tcplog_dumper",0],["Netflix/techreports",0],["Netflix/titus",0],["Netflix/titus-controllers-api",0],["Netflix/titus-resource-pool",0],["Netflix/tslint-config-netflix",0],["Netflix/user2020-metaflow-tutorial",0],["Netflix/webpack-parse-query",0]]' ]]; then
    pass
else
    fail "$VALUE" '[["Netflix/signal-wrapper",0],["Netflix/spectator-cpp",0],["Netflix/tcplog_dumper",0],["Netflix/techreports",0],["Netflix/titus",0],["Netflix/titus-controllers-api",0],["Netflix/titus-resource-pool",0],["Netflix/tslint-config-netflix",0],["Netflix/user2020-metaflow-tutorial",0],["Netflix/webpack-parse-query",0]]'
fi

describe "test-06-07: /view/bottom/5/stars = "

VALUE=$(curl -s "$BASE_URL/view/bottom/5/stars" |tr -d '\n' |sed -e 's/ //g')

if [[ "$VALUE" == '[["Netflix/metrics-client-go",2],["Netflix/titus-controllers-api",2],["Netflix/titus-resource-pool",2],["Netflix/eclipse-jifa",1],["Netflix/eclipse-mat",1]]' ]]; then
    pass
else
    fail "$VALUE" '[["Netflix/metrics-client-go",2],["Netflix/titus-controllers-api",2],["Netflix/titus-resource-pool",2],["Netflix/eclipse-jifa",1],["Netflix/eclipse-mat",1]]'
fi

describe "test-06-08: /view/bottom/10/stars = "

VALUE=$(curl -s "$BASE_URL/view/bottom/10/stars" |tr -d '\n' |sed -e 's/ //g')

if [[ "$VALUE" == '[["Netflix/.github",3],["Netflix/edda-client",3],["Netflix/mantis-rxnetty",3],["Netflix/netflixoss-npm-build-infrastructure",3],["Netflix/titus-kube-common",3],["Netflix/metrics-client-go",2],["Netflix/titus-controllers-api",2],["Netflix/titus-resource-pool",2],["Netflix/eclipse-jifa",1],["Netflix/eclipse-mat",1]]' ]]; then
    pass
else
    fail "$VALUE" '[["Netflix/.github",3],["Netflix/edda-client",3],["Netflix/mantis-rxnetty",3],["Netflix/netflixoss-npm-build-infrastructure",3],["Netflix/titus-kube-common",3],["Netflix/metrics-client-go",2],["Netflix/titus-controllers-api",2],["Netflix/titus-resource-pool",2],["Netflix/eclipse-jifa",1],["Netflix/eclipse-mat",1]]'
fi

report