xquery version "1.0-ml";

module namespace ext = "http://marklogic.com/rest-api/resource/twprofilebyemail";

import module namespace tw = "http://marklogic.com/roxy/twitter" at "/app/models/lib-twitter.xqy";

declare namespace roxy = "http://marklogic.com/roxy";

(: 
 : To add parameters to the functions, specify them in the params annotations. 
 : Example
 :   declare %roxy:params("uri=xs:string", "priority=xs:int") ext:get(...)
 : This means that the get function will take two parameters, a string and an int.
 :)

(:
 : Fetches a list of candidate twitter profiles given an email address of a user.
 :
 : IN DEVELOPMENT - DOESN'T WORK UNLESS YOU HAVE SPECIAL PERMISSION FROM TWITTER FOR THE EMAIL FIELD
 :)
declare 
%roxy:params("email=xs:string")
function ext:get(
  $context as map:map,
  $params  as map:map
) as document-node()*
{
  map:put($context, "output-types", "application/xml"),
  xdmp:set-response-code(200, "OK"),
  document {
    tw:profile-by-email(map:get($params,"email"))
  }
};
