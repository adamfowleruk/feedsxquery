(:
Copyright 2012 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)
(: Author: Adam Fowler <adam.fowler@marklogic.com> :)
xquery version "1.0-ml";

module namespace id="http://marklogic.com/intel/identity";

declare namespace i="http://www.marklogic.com/intel/intercept";
declare namespace n="http://www.marklogic.com/intel/network";
declare namespace ic="http://www.marklogic.com/intel/indexcard";


(: CRUD functions :)

declare function id:get($domain as xs:string,$identity as xs:string) as element(id:identity)? {
   (: TODO :)
   ()
};




(: INTERCEPT ANALYSIS FUNCTIONS :)

declare function id:find-similar-user-intercepts($identity as element(id:identity)) as element(i:intercept)* {
  id:find-similar-user-intercepts($identity/id:service/text(),$identity/id:id/text())
};

declare function id:find-similar-user-intercepts($domain as xs:string,$identity as xs:string) as element(i:intercept)* {
  let $intercepts := /i:intercept[./i:sender/i:identity-ref/i:identity = $identity and ./i:sender/i:identity-ref/i:domain = $domain]
  let $extracts := $intercepts/i:message/i:extract
  let $uris := for $i in $intercepts return fn:base-uri($i)
  let $log1 := xdmp:log(fn:concat("Num intercepts for this id: ",fn:count($intercepts)))
  let $sim := cts:similar-query($intercepts)
  let $res := cts:search((/i:intercept),$sim)
  let $log1 := xdmp:log(fn:concat("Num similar: ",fn:count($res)))
  (: TODO find how to do the next line within a search :)
  
  (: TODO return the below as search results, with relevancy, ordered by relevancy, limited to 30 results :)
  (: return $res[fn:not(./i:sender/i:identity-ref/i:identity = $identity and ./i:sender/i:identity-ref/i:domain = $domain)]:)
  return $res[fn:not(fn:base-uri(.) = $uris)]
};

declare function id:find-similar-user-intercepts-query($domain as xs:string,$identity as xs:string) {
  let $intercepts := (/i:intercept)[./i:sender/i:identity-ref/i:identity = $identity and ./i:sender/i:identity-ref/i:domain = $domain]
  let $log1 := xdmp:log(fn:concat("Num intercepts for this id: ",fn:count($intercepts)))
  let $sim := cts:similar-query($intercepts)
  return $sim
};

declare function id:find-latest-user-intercepts($identity as element(id:identity)) as element(i:intercept)* {
  id:find-latest-user-intercepts-query($identity/id:service/text(),$identity/id:id/text())
};

declare function id:find-latest-user-intercepts-query($domain as xs:string,$identity as xs:string) {
  let $intercepts := (/i:intercept)[./i:sender/i:identity-ref/i:identity = $identity and ./i:sender/i:identity-ref/i:domain = $domain][1 to 10]
  return $intercepts
};


(: IDENTITY MANAGEMENT FUNCTIONS :)
declare function id:get-or-create-identity($domain as xs:string,$identity as xs:string) as element(id:identity)? {
  let $existingdoc := (/id:identity)[./id:service = $domain and ./id:id = $identity][1]
  return
    if ($existingdoc) then 
      $existingdoc
    else
    (:)
      let $identities := (/id:identity)
      let $num := (if ($identities) then fn:count($identities) else 0) + 10
      :)
      let $num := fn:count((/id:identity)) + 10
      let $newuri := fn:concat("/identities/",$num,".xml")
      let $log := xdmp:log(fn:concat("id:get-or-create-identity: Creating identity at uri: ",$newuri, " for domain: ",$domain," and identity: ",$identity))
      let $eval := xdmp:eval(fn:concat('xquery version "1.0-ml";import module namespace id="http://marklogic.com/intel/identity" at "/app/models/lib-identity.xqy";id:do-create-identity("',$newuri,'","',$domain,'","',$identity,'");'))

 (: FAIL!!! CANNOT PERFORM UPDATE IN QUERY CONTEXT - BE CAREFUL WHERE WE CALL THIS - TRYING EVAL:)
      return fn:doc($newuri)/id:identity (: WILL THIS WORK? IS IT COMMITTED YET??? :)
};

declare function id:do-create-identity($newuri as xs:string,$domain as xs:string,$identity as xs:string) {
  xdmp:document-insert($newuri,
<identity xmlns="http://marklogic.com/intel/identity">
 <service>{$domain}</service>
 <name></name>
 <id>{$identity}</id>
 <lastupdated>{fn:current-dateTime()}</lastupdated>
 <url></url>
 <profile>
  <summary></summary>
  <photo-uri></photo-uri>
 </profile>
</identity>)
};


(: NETWORK ANALYSIS FUNCTIONS :)

declare function id:get-mutual($domain as xs:string,$identity as xs:string) as element(n:link)* {
  
  let $recipients := 
    let $ics := (/i:intercept)[./i:sender/i:identity-ref/i:identity = $identity and ./i:sender/i:identity-ref/i:domain = $domain ]
    let $ids := $ics/i:participants/i:identity-ref/i:identity[. != $identity ]/text()
    return fn:distinct-values($ids)
    
let $sentc := fn:count((/i:intercept[./i:sender/i:identity-ref/i:identity = $identity and ./i:sender/i:identity-ref/i:domain = $domain ]/i:sender))
(:
let $muti := (/i:intercept[ ./i:participants/i:identity-ref/i:identity = $identity and $recipients = ./i:sender/i:identity-ref/i:identity]) :)
let $mutual := fn:distinct-values((/i:intercept[ ./i:participants/i:identity-ref/i:identity = $identity and $recipients = ./i:sender/i:identity-ref/i:identity]/i:sender/i:identity-ref/i:identity/text()))
let $recc := fn:count((/i:intercept[ ./i:participants/i:identity-ref/i:identity = $identity and $recipients = ./i:sender/i:identity-ref/i:identity]/i:sender))
(:<n:link><n:identity-ref><n:domain>{$domain}</n:domain><n:identity>{$mid}</n:identity></n:identity-ref></n:link>:)

return
 
  for $mid in $mutual
  let $rec := fn:count((/i:intercept[ ./i:participants/i:identity-ref/i:identity = $identity and $recipients = ./i:sender/i:identity-ref/i:identity][./i:sender/i:identity-ref/i:identity = $mid ]/i:sender))
  return
    let $senttothis := fn:count((/i:intercept[./i:sender/i:identity-ref/i:identity = $identity and $domain  = ./i:sender/i:identity-ref/i:domain and ./i:participants/i:identity-ref/i:identity = $mid]/i:sender))
    let $identity := id:get-or-create-identity($domain,$mid)
    let $ic := id:get-or-create-index-card($identity)
    return
      <n:link>
        <n:identity-uri>{fn:base-uri($ic)}</n:identity-uri>
        <n:identity-ref><n:domain>{$domain}</n:domain><n:identity>{$mid}</n:identity></n:identity-ref>
        <n:link-summary><n:totalsent>{$senttothis}</n:totalsent><n:totalreceived>{$rec}</n:totalreceived></n:link-summary>
      </n:link> 
  
  (:)
  
  
(:let $senti := (/i:intercept[./i:sender/i:identity-ref/i:identity = $identity and $domain  = ./i:sender/i:identity-ref/i:domain ]) :)
let $recipients := fn:distinct-values(/i:intercept[./i:sender/i:identity-ref/i:identity = $identity and $domain  = ./i:sender/i:identity-ref/i:domain ]/i:participants/i:identity-ref/i:identity[. != $identity]/text())
let $sentc := fn:count((/i:intercept[./i:sender/i:identity-ref/i:identity = $identity and $domain  = ./i:sender/i:identity-ref/i:domain ]))
(:
let $muti := (/i:intercept[ ./i:participants/i:identity-ref/i:identity = $identity and $recipients = ./i:sender/i:identity-ref/i:identity]) :)
let $mutual := fn:distinct-values((/i:intercept[ ./i:participants/i:identity-ref/i:identity = $identity and $recipients = ./i:sender/i:identity-ref/i:identity]/i:sender/i:identity-ref/i:identity/text()))
let $recc := fn:count((/i:intercept[ ./i:participants/i:identity-ref/i:identity = $identity and $recipients = ./i:sender/i:identity-ref/i:identity]))
(:<n:link><n:identity-ref><n:domain>{$domain}</n:domain><n:identity>{$mid}</n:identity></n:identity-ref></n:link>:)

return
 
  for $mid in $mutual
  let $rec := ((/i:intercept[ ./i:participants/i:identity-ref/i:identity = $identity and $recipients = ./i:sender/i:identity-ref/i:identity][./i:sender/i:identity-ref/i:identity = $mid ]))
  return
    let $senttothis := ((/i:intercept[./i:sender/i:identity-ref/i:identity = $identity and $domain  = ./i:sender/i:identity-ref/i:domain ])[./i:participants/i:identity-ref/i:identity = $mid])
    let $identity := id:get-or-create-identity($domain,$mid)
    let $ic := id:get-or-create-index-card($identity)
    return
      <n:link>
        <n:identity-uri>{fn:base-uri($ic)}</n:identity-uri>
        <n:identity-ref><n:domain>{$domain}</n:domain><n:identity>{$mid}</n:identity></n:identity-ref>
        <n:link-summary><n:totalsent>{fn:count($senttothis)}</n:totalsent><n:totalreceived>{fn:count($rec)}</n:totalreceived></n:link-summary>
      </n:link>
  :)
};

(: returns URIs of identity documents :)
declare function id:get-identities($ic as element(ic:index-card)) as xs:string* {
  $ic/ic:identity-refs/ic:identity-ref/text()
};

declare function id:get-identity-refs($uris as xs:string*) as element(id:identity)* {
  let $l := xdmp:log(fn:concat("id:get-identity-refs: Got ",fn:count($uris)," URIs"))
  for $id in $uris
  return fn:doc($id)/id:identity
};

declare function id:get-or-create-index-card($identity as element(id:identity)) as element(ic:index-card)? {
  let $uri := fn:base-uri($identity)
  let $existingdoc := (/ic:index-card)[./ic:identity-refs/ic:identity-ref/text() = $uri][1]
  return
    if ($existingdoc) then 
      $existingdoc
    else
      let $cards := (/ic:index-card)
      let $num := (if ($cards) then fn:count($cards) else 0) + 10
      let $newuri := fn:concat("/indexcard/",$num,".xml")
      let $log := xdmp:log(fn:concat("id:get-or-create-index-card: Creating index-card at uri: ",$newuri, " for id uri: ",$uri))
      let $eval := xdmp:eval(fn:concat('xquery version "1.0-ml";import module namespace id="http://marklogic.com/intel/identity" at "/app/models/lib-identity.xqy";id:do-create-index-card("',$newuri,'","',$uri,'","',$num,'");'))

 (: FAIL!!! CANNOT PERFORM UPDATE IN QUERY CONTEXT - BE CAREFUL WHERE WE CALL THIS - TRYING EVAL:)
      return fn:doc($newuri)/ic:index-card (: WILL THIS WORK? IS IT COMMITTED YET??? :)
};

declare function id:do-create-index-card($newuri as xs:string,$iduri as xs:string,$file-number as xs:string) {
  xdmp:document-insert($newuri,
<index-card xmlns="http://www.marklogic.com/intel/indexcard">
 <file-number>{$file-number}</file-number>
 <name>Unknown</name>
 <gender>Unknown</gender>
 <summary></summary>
 <identity-refs>
  <identity-ref>{$iduri}</identity-ref>
 </identity-refs>
</index-card>

)

};

declare function id:add-identity-to-index-card($index-card as element(ic:index-card), $identity as element(id:identity)) {
  if ($index-card/ic:identity-ref/ic:identity-ref[. = fn:base-uri($identity)]) then
    ()
  else
    let $idref := <ic:identity-ref>{fn:base-uri($identity)}</ic:identity-ref>
    return xdmp:node-insert-child($index-card/ic:identity-refs,$idref)
};

declare function id:get-index-card($domain as xs:string,$identity as xs:string) as element(ic:index-card)? {
  let $identity := /id:identity[./id:service = $domain and ./id:id = $identity]
  let $iduri := fn:base-uri($identity)
  let $index-card := /ic:index-card[./ic:identity-refs/ic:identity-ref = $iduri]
  return $index-card
};

declare function id:get-network($domain as xs:string,$identity as xs:string) as element(n:network)? {
  let $l := xdmp:log(fn:concat("id:get-network: Domain: ",$domain,", identity: ",$identity))
  let $index-card := id:get-index-card($domain,$identity)
  return id:get-network-from-index-card($index-card)
};

declare function id:get-network-from-index-card-uri($uri as xs:string) as element(n:network)? {
  let $index-card := fn:doc($uri)/ic:index-card
  return id:get-network-from-index-card($index-card)
};

declare function id:get-network-from-index-card($index-card as element(ic:index-card)) as element(n:network)? {
  let $l2 := xdmp:log(fn:concat("id:get-network: Index card: ",fn:string($index-card)))
  let $iduris := id:get-identities($index-card)
  let $l3 := xdmp:log(fn:concat("id:get-network: Identity URIs: ", $iduris))
  let $idrefs := id:get-identity-refs($iduris)
  let $l4 := xdmp:log(fn:concat("id:get-network: idrefs: ",(for $idr in $idrefs return fn:string($idr))))
  let $mutual := 
    for $idref in $idrefs
    return id:get-mutual($idref/id:service,$idref/id:id)
  let $sentc := fn:sum(xs:int($mutual/n:link/n:link-summary/n:totalsent/text()))
  let $recc := fn:sum(xs:int($mutual/n:link/n:link-summary/n:totalreceived/text()))
  return 
<n:network><n:principle><n:identity-uri>{fn:base-uri($index-card)}</n:identity-uri>
  {
    for $id in $idrefs
    return
    <n:identity-ref><n:domain>{$id/id:service/text()}</n:domain><n:identity>{$id/id:id/text()}</n:identity></n:identity-ref>
  }
  <n:totalsent>{$sentc}</n:totalsent>
  <n:totalreceived>{$recc}</n:totalreceived>
 </n:principle>
 <n:summary><n:totalsent>{$sentc}</n:totalsent><n:totalreceived>{$recc}</n:totalreceived></n:summary><n:links>
 {for $m in $mutual return $m}
 
  </n:links></n:network>
};
