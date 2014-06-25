xquery version "1.0-ml";

module namespace fe = "http://marklogic.com/intel/feeds";

import module namespace te="http://marklogic.com/libs/temporal" at "/app/models/lib-temporal.xqy";

declare namespace f="http://www.marklogic.com/intel/feeds";
declare namespace i="http://www.marklogic.com/intel/intercept";

(: core libraries :)

import module namespace oa = "http://marklogic.com/ns/oauth" at "/app/models/oauth.xqy";
import module namespace json = "http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";


import module namespace oauth2 = "oauth2" at "/app/models/oauth2.xqy";

declare namespace jb = "http://marklogic.com/xdmp/json/basic";


(: collector libraries :)
import module namespace tw = "http://marklogic.com/roxy/twitter" at "/app/models/lib-twitter.xqy";



declare default function namespace "http://www.w3.org/2005/xpath-functions";

(: UTILITY FUNCTIONS :)
declare function fe:get-last-result($feedid as xs:string) as element(fe:feed-result)? {
  let $inlog := xdmp:log("fe:get-last-result")
  let $feeds :=
    for $feed in /fe:feed-result[./fe:feed-ref = $feedid]
    order by $feed/fe:last-ran descending
    return $feed
  return $feeds[1]
};

declare function fe:run-feeds() as element(fe:feed-result)* {
  let $log := xdmp:log("RUNFEEDS CALLED IN FEEDS LIB")
  for $fc at $idx in /f:feed-config/f:feeds/f:feed
  let $fb := xdmp:log(fn:concat("*** fe:run-feeds called for ",$fc/@id/fn:string()))
  return
    fe:run-feed-offset($fc/@id/fn:string(),$idx)
};

declare function fe:run-feed($feedid as xs:string) as element(fe:feed-result) {
  xdmp:log(fn:concat("*** Run feed called for ",$feedid)),
  fe:run-feed-offset($feedid,0)
};


declare function fe:get-feed-config() as element(f:feed-config)? {
  fn:doc("/admin/config/feeds.xml")/f:feed-config
};
declare function fe:list-feeds() as element(f:feed)*{
  fe:get-feed-config()/f:feeds/f:feed
};

declare function fe:list-feeds-of-type($source as xs:string) {
  fe:list-feeds()[./source eq $source]
};

declare function fe:create-feed($feed as element(f:feed)) {
  xdmp:node-insert-child(fe:get-feed-config()/f:feeds,$feed)
};

declare function fe:get-feed($feedid as xs:string) as element(f:feed)? {
  fe:list-feeds()[@id eq $feedid]
};

declare function fe:update-feed($feed as element(f:feed)) {
  xdmp:node-replace(fe:get-feed($feed/@id),$feed)
};

declare function fe:delete-feed($feedid as xs:string) {
  xdmp:node-delete(fe:get-feed($feedid))
};

(: PUBLIC FUNCTIONS :)
(:
 : Executes a feed with the required id. Could be called manually or as a timed activity.
 : Figures out itself when it was last ran in order to save resources.
 : NB all collectors should guarantee that no communication is intercepted twice
 :)
declare function fe:run-feed-offset($feedid as xs:string,$offset as xs:int) as element(fe:feed-result) {
  let $inlog := xdmp:log(fn:concat("*** fe:run-feed for ",$feedid," at offset ",$offset))
  (: TODO add exception handling in order to fail gracefully :)

  (: Get feed config :)
  let $fc := fe:get-feed($feedid)

  (: get last ran info :)
  let $lr := fe:get-last-result($feedid)
  let $sincew3c := xs:dateTime($lr/fe:last-ran/text())
  let $since := xs:long(($sincew3c - xs:dateTime("1970-01-01T00:00:00-00:00")) div xs:dayTimeDuration('PT0.001S'))

  (: if twitter, run twitter collector :)
  (: NB collectors are responsible themselves for storing intercepts in the DB, not this function :)
  let $interceptrefs as element(fe:intercept-ref)* :=
    if ($fc/f:source/text() = "twitter") then
      fe:run-collector-twitter($fc,$since) (: pass in unix epoch instead of w3c :)
    else if ($fc/f:source/text() = "twitterprofiles") then
      fe:run-collector-twitter-profiles($fc,$since)
    else if ($fc/f:source/text() = "facebook") then
      fe:run-collector-facebook-posts($fc,$since) (: pass in unix epoch instead of w3c :)
    else ()

  (: update last ran info :)
  let $lrn :=
    <feed-result xmlns="http://marklogic.com/intel/feeds">
     <feed-ref>{$feedid}</feed-ref>
     <success>true</success>
     <last-ran>{fn:current-dateTime()}</last-ran>
     <collected>
      {$interceptrefs}
     </collected>
    </feed-result>

  let $inres := xdmp:document-insert(fn:concat("/admin/config/feed-results/",(fn:count(/fe:feed-result) + 10 + $offset),".xml"), $lrn) (: todo add feed results collection ref :) (: todo ensure unique id :)

  (: return last ran info :)
  return $lrn
};

(:
 : Example feed format:-{
   "data": [
      {
         "id": "202817646394932_351118261648072",
         "from": {
            "name": "Bablake (Official)",
            "category": "Education",
            "id": "202817646394932"
         },
         "message": "Our first report of the season from the Old Wheatleyans RFC, now playing in the Midlands Division 3 West (South), includes a mention of Richard Drury's 7 tries on his return from injury.",
         "picture": "http://external.ak.fbcdn.net/safe_image.php?d=AQCouiM5PU8VrmJp&w=90&h=90&url=http\u00253A\u00252F\u00252Fwww.bablake.com\u00252Fuploads\u00252Fnews\u00252Fimages\u00252Fbig\u00252F2012-10-08-81608.jpg",
         "link": "http://www.bablake.com/newsroom.php?item=1018",
         "name": "Bablake | Newsroom",
         "caption": "www.bablake.com",
         "description": "Following promotion last season and a fine cup run which ended agonisingly one match from Twickenham, the Old Wheatleyans RFC, now coached by Lee Cassell and former Welsh international and Bablake Deputy Head Ron Jones, has made a spirited start to its Midlands Division 3 West (South) campaign.",
         "icon": "http://static.ak.fbcdn.net/rsrc.php/v2/yD/r/aS8ecmYRys0.gif",
         "type": "link",
         "status_type": "shared_story",
         "created_time": "2012-10-07T11:11:12+0000",
         "updated_time": "2012-10-07T11:11:12+0000"
      },
      ... ] }
 :
 :)
declare function fe:run-collector-facebook-posts($fc as element(f:feed), $since as xs:long?) as element(fe:intercept-ref)* {
  (: get query param from feed config :)
  let $inlog := xdmp:log("fe:run-collector-facebook-posts")
  (: FETCH RESULTS :)
  (: load feed parameters :)
  let $method := $fc/f:params/f:param[./f:name = "method"]/f:value/text()
  let $baseuri := $fc/f:params/f:param[./f:name = "document-base-uri"]/f:value/text()

  return
    if ($method = "public") then
      let $q:= $fc/f:params/f:param[./f:name = "query"]/f:value/text()
      return fe:run-collector-facebook-posts-public($fc,$since,$q,$baseuri)
    else if ($method = "userfeed") then
      let $userid := $fc/f:params/f:param[./f:name = "userid"]/f:value/text()
      return fe:run-collector-facebook-posts-feed($fc,$since,$userid,$baseuri)
    else if ($method = "usercorpus") then
      fe:run-collector-facebook-posts-user-corpus($fc,$since,$baseuri)
    else ()

};

declare function fe:run-collector-facebook-posts-user-corpus($fc as element(f:feed), $since as xs:long,$baseuri as xs:string) as element(fe:intercept-ref)* {

  let $users := fn:distinct-values((fn:collection("http://marklogic.com/collections/intercepts")/i:intercept)[./i:collector-ref/i:type/text() = "facebook"]/i:sender/i:identity-ref/i:service-id/text()) (: participants would exponentially grow the corpus :)
    let $limit := 1000
  let $log := xdmp:log(fn:concat("fe:run-collector-facebook-posts-user-corpus for ",fn:count($users)," users"))
  return
    for $userid in $users
    let $last := xs:long((xs:dateTime(
      (for $d in (fn:collection("http://marklogic.com/collections/intercepts")/i:intercept)[./i:collector-ref/i:feed = $fc/@id/fn:string() and ./i:sender/i:identity-ref/i:service-id/text() = $userid]/i:message/i:sent
        order by $d descending
        return $d)[1]/text()) - xs:dateTime("1970-01-01T00:00:00-00:00")) div xs:dayTimeDuration('PT0.001S'))
    let $log2 := xdmp:log("calling facebookSearchUserPosts")
    let $posts := oauth2:facebookSearchUserPosts($userid,$last,$limit)
    let $log3 := xdmp:log(fn:concat("result of facebookSearchUserPosts: ",$posts))
    let $pxml := json:transform-from-json($posts)
    let $tempinsert := xdmp:document-insert(fn:concat("/admin/temp-facebook-posts-",$fc/@id/fn:string(),"-user-",$userid,".xml"),$pxml)
    let $log4 := xdmp:log("done temp insert")

    return
      for $post at $idx in $pxml/jb:data/jb:json
      return fe:run-collector-facebook-post-to-intercept($fc,$baseuri,$post,$idx)
};

declare function fe:run-collector-facebook-posts-feed($fc as element(f:feed), $since as xs:long,$userid,$baseuri as xs:string) as element(fe:intercept-ref)* {

  (: get posts in feed :)
  let $limit := 1000
  let $last := xs:long((xs:dateTime(
    (for $d in fn:collection("http://marklogic.com/collections/intercepts")/i:intercept[./i:collector-ref/i:feed = $fc/@id/fn:string()]/i:message/i:sent
      order by $d descending
      return $d)[1]/text()) - xs:dateTime("1970-01-01T00:00:00-00:00")) div xs:dayTimeDuration('PT0.001S'))

  let $posts := oauth2:facebookSearchUserPosts($userid,$last,$limit)

  let $pxml := json:transform-from-json($posts)
  let $tempinsert := xdmp:document-insert(fn:concat("/admin/temp-facebook-posts-",$fc/@id/fn:string(),".xml"),$pxml)

  (: TODO get up to 1000 posts at a time :)
  (: TODO handle mentions :)

  return
    for $post at $idx in $pxml/jb:data/jb:json
    return fe:run-collector-facebook-post-to-intercept($fc,$baseuri,$post,$idx)
};

declare function fe:run-collector-facebook-post-to-intercept($fc as element(f:feed), $baseuri as xs:string,$post as element(jb:json),$idx as xs:long) as element(fe:intercept-ref)? {

    (: Ensure each is unique :)
    let $exists := (fn:collection("http://marklogic.com/collections/intercepts")/i:intercept[./i:collector-ref/i:type = "facebook" and ./i:message/i:serviceurl = $post/jb:id])
    return
      if ($exists) then ()
      else
        let $lid := xdmp:log(fn:concat("Facebook post ",$post/jb:id/text()))
        let $author := $post/jb:from/jb:id/text()
        let $authorname := $post/jb:from/jb:name/text()
        let $rawtext := fn:string-join(($post/jb:message/text(),$post/jb:story/text(),$post/jb:link/text(),$post/jb:name/text(),$post/jb:caption/text(),$post/jb:description/text())," :: ")
        let $created := te:string-to-w3c($post/jb:created__time/text())
        let $intercept :=
      <intercept xmlns="http://www.marklogic.com/intel/intercept">
      <sender>
      <location>
      <placename></placename>
      </location>
      <identity-ref>
      <domain>facebook</domain>
      <identity>{$authorname}</identity>
      <service-id>{$author}</service-id>
      </identity-ref>
      </sender>

      <participants>
      <identity-ref>
      <domain>facebook</domain>
      <identity>{$authorname}</identity>
      <service-id>{$author}</service-id>
      </identity-ref>
      { (: People message is directed to :)
        for $pp in $post/jb:to/jb:data/jb:json
        return

      <identity-ref>
      <domain>facebook</domain>
      <identity>{$pp/jb:name/text()}</identity>
      <service-id>{$pp/jb:id/text()}</service-id>
      </identity-ref>

      }
      { (: message tags :)
        for $pp in $post/jb:message__tags/jb:*/jb:json[./jb:type = "user"]
        return

      <identity-ref>
      <domain>facebook</domain>
      <identity>{$pp/jb:name/text()}</identity>
      <service-id>{$pp/jb:id/text()}</service-id>
      </identity-ref>

      }
      { (: People that have liked, and thus read, the post :)
        for $pp in $post/jb:likes/jb:data/jb:json
        return

      <identity-ref>
      <domain>facebook</domain>
      <identity>{$pp/jb:name/text()}</identity>
      <service-id>{$pp/jb:id/text()}</service-id>
      </identity-ref>

      }
      </participants>

      <message>
      <raw>{$post}</raw>
      <extract>{$rawtext}</extract>
      <serviceurl>{$post/jb:id/text()}</serviceurl>
      <topics>
      </topics>
      <sent>{$created}</sent>
      </message>

      <collector-ref>
      <type>facebook</type>
      <feed>{$fc/@id/fn:string()}</feed>
      <collected>{fn:current-dateTime()}</collected>
      </collector-ref>
      </intercept>
      let $docuri := fn:concat($baseuri,"facebook-post-",$idx,"-",$post/jb:id/text(),".xml")
      let $dbresult := xdmp:document-insert($docuri,$intercept,xdmp:default-permissions(),("http://marklogic.com/collections/intercepts")) (: TODO collection, sensible unique ID :)
      return <fe:intercept-ref>{$docuri}</fe:intercept-ref>
};

declare function fe:run-collector-facebook-posts-public($fc as element(f:feed), $since as xs:long,$q as xs:string,$baseuri as xs:string) as element(fe:intercept-ref)* {

  (: get posts in feed :)
  let $log := xdmp:log(fn:concat("fe:run-collector-facebook-posts-public for ",$fc/@id/fn:string(),", q: ",$q,", baseuri: ",$baseuri))
  let $limit := 1000
  let $last := xs:long((xs:dateTime(
    (for $d in /i:intercept[./i:collector-ref/i:feed = $fc/@id]/i:message/i:sent
      order by $d descending
      return $d)[1]/text()) - xs:dateTime("1970-01-01T00:00:00-00:00")) div xs:dayTimeDuration('PT0.001S'))
  let $log2 := xdmp:log(fn:concat("limit: ",$limit,", last: ",$last,", q: ",$q))
  let $posts := oauth2:facebookSearchPublicPosts($q,$last,$limit)
  let $pxml := json:transform-from-json($posts)
  let $tempinsert := xdmp:document-insert(fn:concat("/admin/temp-facebook-posts-",fn:string($fc/@id/fn:string()),".xml"),$pxml)

  (: TODO get up to 1000 posts at a time :)
  (: TODO handle mentions :)
  let $logp := xdmp:log(fn:concat("fe:run-collector-facebook-posts-public posts received: ",fn:count($pxml/jb:data/jb:json),", JSON: ",$posts))
  return
    for $post at $idx in $pxml/jb:data/jb:json
    return fe:run-collector-facebook-post-to-intercept($fc,$baseuri,$post,$idx)
};

declare function fe:run-collector-twitter-profiles($fc as element(f:feed), $since as xs:long?) as element(fe:intercept-ref)* {
  let $inlog := xdmp:log("fe:run-collector-twitter-profiles")

  let $baseuri := $fc/f:params/f:param[./f:name = "document-base-uri"]/f:value/text()

  (: Fetch all unique twitter screen names from intercepts :)
  let $screennames := /i:intercept[./i:collector-ref/i:type = "twitter"]/i:sender/i:identity-ref/i:service-id/text()
  (: Fetch all unique twitter screen names from existing profiles :)
  let $profilenames := /i:profile/i:identity-ref/i:service-id/text()
  (: Fetch the profiles we don't yet know about :)
  let $newnames := $screennames except $profilenames (: eliminates duplicates itself :)

  let $out :=
    for $name in $newnames
    let $thename := fn:substring($name,2)
    return
      let $profile := tw:get-profile($thename)
      let $docuri := fn:concat($baseuri,"twitter-profile-",$thename,".xml")
      let $dbresult := xdmp:document-insert($docuri,$profile,xdmp:default-permissions(),("http://marklogic.com/collections/profiles")) (: TODO collection, sensible unique ID :)
      return <fe:profile-ref>{$docuri}</fe:profile-ref>
  return $out
};

(:
 : Collects tweets from Twitter. Could be as a result of a text search, the collector user's own feed, or a point radius (geosearch)
 :)
declare function fe:run-collector-twitter($fc as element(f:feed), $since as xs:long?) as element(fe:intercept-ref)* {
  let $inlog := xdmp:log("fe:run-collector-twitter")
  (: FETCH RESULTS :)
  (: load feed parameters :)
  let $method := $fc/f:params/f:param[./f:name = "method"]/f:value/text()
  let $baseuri := $fc/f:params/f:param[./f:name = "document-base-uri"]/f:value/text()
  let $feedname := $fc/@id/fn:data(.)
  (:
  let $lastid :=
    (for $i in /i:intercept[./i:collector-ref/i:type = "twitter"]/i:message/i:serviceurl
    (: (for $i in /i:intercept[./i:collector-ref/i:feed = $fc/@id]/i:message/i:serviceurl:)
    order by xs:long($i/text()) descending
    return $i)[1]/text()
    :)
  (: let $lastid := $idr)) :)
    let $tweets :=
    (: if query, execute query :)
    if ($method = "query") then
    (
      let $l := xdmp:log("EXECUTING QUERY")
      return tw:search($fc/f:params/f:param[./f:name = "query"]/f:value/text())
    ) else if ($method = "myfeed") then
        let $l := xdmp:log("EXECUTING MYFEED")
        (:  if user feed, get user feed :)
        let $lastid := (fn:max(xs:long(((fn:collection($feedname)/i:intercept)[./i:collector-ref/i:type = "twitter"]/i:message/i:serviceurl))), 1)[1]
        return tw:get-user-feed($lastid)
    else if ($method = "geo") then
        let $l := xdmp:log("EXECUTING GEO SEARCH")
        let $q:= ($fc/f:params/f:param[./f:name = "query"]/f:value/text()," ")[1]
        let $l := xdmp:log(fn:concat("EXECUTING GEO SEARCH query: '",$q,"'"))
        let $lat:= $fc/f:params/f:param[./f:name = "latitude"]/f:value/text()
        let $l := xdmp:log(fn:concat("EXECUTING GEO SEARCH lat: ",$lat))
        let $lon:= $fc/f:params/f:param[./f:name = "longitude"]/f:value/text()
        let $l := xdmp:log(fn:concat("EXECUTING GEO SEARCH lon: ",$lon))
        let $rad:= $fc/f:params/f:param[./f:name = "radiusmiles"]/f:value/text()
        let $l := xdmp:log(fn:concat("EXECUTING GEO SEARCH radiusmiles: ",$rad))
        return tw:geo-search($q,$lat,$lon,$rad)
    else ()
      (: TODO if geosearch, perform geo search :)

      (: PROCESS RESULTS :)
      (: TODO remove this debug line :)
      let $l := xdmp:log(fn:concat("RECEIVED ",fn:count($tweets/jb:response/jb:json)," TWEETS"))
      (: let $tempinsert := xdmp:document-insert("/admin/temp-tweets.xml",$tweets) :)
      let $intercepts :=
      for $tweet at $idx in $tweets//jb:response/jb:json
      let $logt := xdmp:log(fn:concat("tweet id ",$tweet/jb:id/text()))
      (: check that we haven't already processed this tweet :)
      let $existing := (/i:intercept[./i:message/i:serviceurl = $tweet/jb:id])
      return
      if ($existing) then (xdmp:log(fn:concat("Skipping already collected tweet: ",$tweet/jb:id/text()))) else
      (: extract entity information :)
      (: extract words starting with # as topics :)
      (: trim punctuation out of end of topics - .,!: etc. - no need, provided by twitter API directly :)
      let $author := $tweet/jb:user/jb:screen__name
      let $topics := $tweet/jb:entities/jb:hashtags/jb:json/jb:text
      let $users := $tweet/jb:entities/jb:user__mentions/jb:json/jb:screen__name
      let $coords := ($tweet/jb:coordinates/jb:coordinates)[1]
      let $rawtext := $tweet/jb:text/text()
      let $intercept :=
      <intercept xmlns="http://www.marklogic.com/intel/intercept">
      <sender>
      <location>
      <placename>{$tweet/jb:place/jb:full__name/text()}</placename>
      {if (fn:not(fn:empty($coords))) then
        <coords>
        <lon>{xs:double($coords/jb:item[1]/text())}</lon>
        <lat>{xs:double($coords/jb:item[2]/text())}</lat>
        </coords>
        else ()
      }
      </location>
      <identity-ref>
      <domain>twitter</domain>
      <identity>@{$author/text()}</identity>
      <service-id>@{$author/text()}</service-id>
      </identity-ref>
      </sender>

      <participants>
      <identity-ref>
      <domain>twitter</domain>
      <identity>@{$author/text()}</identity>
      <service-id>@{$author/text()}</service-id>
      </identity-ref>
      {
        for $user in $users
        return
        <identity-ref>
        <domain>twitter</domain>
        <identity>@{$user/text()}</identity>
      <service-id>@{$user/text()}</service-id>
        </identity-ref>
      }
      </participants>

      <message>
      <raw>{$tweet}</raw>
      <extract>{$rawtext}</extract>
      <serviceurl>{$tweet/jb:id/text()}</serviceurl>
      <topics>
      {
        for $topic in $topics
        return
        <topic>{$topic/text()}</topic>
      }
      </topics>
      <sent>{te:date($tweet/jb:created__at/text())}</sent>
      </message>

      <collector-ref>
      <type>twitter</type>
      <feed>{$fc/@id/fn:string()}</feed>
      <collected>{fn:current-dateTime()}</collected>
      </collector-ref>
      </intercept>
      let $docuri := fn:concat($baseuri,"tweet-",$idx,"-",$tweet/jb:id/text(),".xml")
      let $dbresult := xdmp:document-insert($docuri,$intercept,xdmp:default-permissions(),("http://marklogic.com/collections/intercepts",$feedname)) (: TODO collection, sensible unique ID :)
      return <fe:intercept-ref>{$docuri}</fe:intercept-ref>
      (: Places will be extracted automatically via alerting feature attached to each place name :)
      (: add intercepts in to DB :)

      return $intercepts
};
