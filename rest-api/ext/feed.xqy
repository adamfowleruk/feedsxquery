xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/feed";

declare namespace roxy = "http://marklogic.com/roxy";

declare namespace json = "http://marklogic.com/xdmp/json/basic";

import module namespace f = "http://marklogic.com/intel/feeds" at "/app/models/lib-feeds.xqy";


(: 
 : To add parameters to the functions, specify them in the params annotations. 
 : Example
 :   declare %roxy:params("uri=xs:string", "priority=xs:int") ext:get(...)
 : This means that the get function will take two parameters, a string and an int.
 :)

(:
 :)
declare 
%roxy:params("feed=xs:string")
function ext:post(
    $context as map:map,
    $params  as map:map,
    $input   as document-node()*
) as document-node()*
{
  map:put($context, "output-types", "application/xml"),
  xdmp:set-response-code(200, "OK"),
  document { 
    f:run-feed((map:get($params,"name"),"chester-tweets")[1])
  }
};
