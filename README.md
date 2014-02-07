# Feeds XQuery Libraries

This set of XQuery files allow developers using MarkLogic Server to pull data from a variety of sources. The initial
aim is to pull down social media information, including tweets, facebook posts, and profile information. This is to
power social media analytics applications written for MarkLogic Server.

## Design

There is an overarching file called lib-feeds.xqy that manages the feeds. This is called using a REST API endpoint
from a timed CRON script (for example), or batch file, or adhoc through other application XQuery code.

run-feed() in the lib-feeds file is the main entry point. This takes a feed name as a parameter. The content database
against which this code is running should have a feed configuration XML file (see the samples folder) which defines
the named feeds. This allows feeds to be reconfigured without republishing code.

The lib-feeds code reads the configuration, executing the relevant collector function within itself. It also passes
the parameters to that function.

Although it is left up to the collection function as to what it generates in MarkLogic, it is anticipated that each
function returns a list of intercept-ref elements. An Intercept is anything collected from a public source, be it
twitter or a blog entry.

There is a standard Envelope pattern suggested for collected information. This uses an XML structure for each
individual collected document (tweet, profile, blog post) called an intercept. This defines generic information that
can be extracted from most sources.

The intercept XML envelope pattern includes fields for sender, recipients, message extract, topics, location (name
and longitude/latitude). This pattern enables all sources to be treated the same from a high level search results
rendering standpoint.

There are several dependancies for this library. OAuth and OAuth2 and a lower level twitter library are all used
to manage communication to sites like Facebook and Twitter.

## Using the libraries

Most services require that you authenticate to them in order to perform a search. Thus your first step is to 
register for an account. This is certainly true for twitter. Facebook does not require this. Note that some
services do allow anonymous access but instead rate limit your requests.

The library is designed to execute fast by pulling down a low number (100) of posts within approx 2-3 seconds.
By running a named feed every five minutes it's possible to pull down a lot of tweets very quickly. A recent
example I pulled down 65000 tweets in 24 hours. These were tweets within a radius of 20 miles from an average 
sized city.

This was using the geosearch twitter collection method - this works by performing a radius search on twitter.
Any tweets geocoded within that area - or, importantly, any tweets from users whose profiles say they live in
a town in that area - are captured. In my experience approx 12% (10000) of these geosearch sourced tweets are
geocoded with longitude and latitude.

The coordinate systems used on social media is typically EPSG900913. This is the same used by google, bing maps.
It is not the same used by MarkLogic Server, which uses EPSG4326 (WGS84) coordinates. This library uses my own
developed coordinates library to convert these on the fly. Also be aware this library supports conversion from
UK OSGB36 and National Grid Reference coordinates to EPSG4326 also.

To invoke these from curl, install the rest extension feed.xqy (using Roxy perhaps) found in the rest-api/ext
folder. Invoke this with a POST request to /v1/resources/feed with the parameters name set to your feed name.

NOTE: Posting to this URL with a query string ?name=FEEDNAME will not work - the REST API by default ignores
query string parameters on a POST.

Alternatively you can register a task with the MarkLogic task server to invoke run-feed(feedname) in
lib-feeds.xqy.

## Methods supported

|Collector source name|Description|Parameters Supported|
|---|---|---|
|twitter|Tweet search|method(myfeed or geo or query), query, document-base-uri, latitude, longitude, radiusmiles|
|facebook|Facebook posts search|method(public), query, document-base-uri|

Note that lon/lat/radius on the twitter feed only work with geo mode.

To set up authentication, edit lines 34 and 35 of lib-twitter.xqy in order to provide your own app secret keys.
Read the twitter API website for details on this. You have to create a dummy app under your account to use this
library.

## Samples

Please look in the samples folder for example feed configurations. Note that there is a lot of in progress code
in these libraries. These have not been documented above. Those methods above are ones I know to work well and
are high performance.

## Help / Feedback

Go to GitHub.com and add an issue to the issue tracker.
