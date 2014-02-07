xquery version "1.0-ml";
module namespace oauth2 = "oauth2";
declare namespace xdmphttp="xdmp:http";

declare function oauth2:getAppAccessToken($appid,$appsecret) {
  let $resp := xdmp:http-get(fn:concat("https://graph.facebook.com/oauth/access_token?client_id=",$appid,"&amp;client_secret=",$appsecret,"&amp;grant_type=client_credentials"))
  (: get response text in format access_token=YOUR_APP_ACCESS_TOKEN   :)
  return fn:tokenize($resp[2],"=")[fn:last()]
};

(:~
 : Fetch the user profile info for the given provider, basically a router function
 : @param $provider the provider name corresponding the provider config setup
 : @param $oauth_token_data the oauth2 access_token for the current users session
 : @return the provider-data node() block
 :)
declare function oauth2:getUserProfileInfo($provider, $oauth_token_data)  {
    let $access_token := map:get($oauth_token_data, "access_token")    
    return
    if($provider = "facebook") then
        oauth2:facebookUserProfileInfo($access_token) 
    else
        oauth2:githubUserProfileInfo($access_token) 
};

declare function oauth2:getUserToken($username,$appid,$appsecret) {
  let $loginuri := "https://www.facebook.com/login.php?login_attempt=1&amp;fbconnect=1&amp;display=page&amp;next=https%3A%2F%2Fwww.facebook.com%2Fdialog%2Fpermissions.request%3F_path%3Dpermissions.request%26app_id%3D127268677421110%26redirect_uri%3Dhttp%253A%252F%252Flocalhost%253A8098%252Ffbreturn%26display%3Dpage%26response_type%3Dcode%26fbconnect%3D1%26from_login%3D1%26client_id%3D127268677421110&amp;legacy_return=1"
  let $loginpage := xdmp:http-post($loginuri,<options xmlns='xdmp:http-get'><format xmlns='xdmp:document-get'>text</format></options>)
  (: FB login URI: https://www.facebook.com/login.php?login_attempt=1&fbconnect=1&display=page&next=https%3A%2F%2Fwww.facebook.com%2Fdialog%2Fpermissions.request%3F_path%3Dpermissions.request%26app_id%3D127268677421110%26redirect_uri%3Dhttp%253A%252F%252Flocalhost%253A8098%252Ffbreturn%26display%3Dpage%26response_type%3Dcode%26fbconnect%3D1%26from_login%3D1%26client_id%3D127268677421110&legacy_return=1 :)
  
  (: get security cookie and send with future requests Set-Cookie :)
  (: c_user=100004466529652; path=/; domain=.facebook.com datr=NlaHTrfdOpSoYWG5crolir6t; expires=Tue, 07-Oct-2014 10:27:44 GMT; path=/; domain=.facebook.com; httponly fr=03sU1vMDDlLN7hHGP.AWVOPA0-CFawYbaaHWHMZxVNy5g.BP2Yvw.Dp.AWXeiwKC; expires=Tue, 06-Nov-2012 10:27:45 GMT; path=/; domain=.facebook.com; httponly lu=RQFPON-XLfh6ZTM72jh-ESDw; expires=Tue, 07-Oct-2014 10:27:45 GMT; path=/; domain=.facebook.com; httponly reg_fb_gate=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; path=/; domain=.facebook.com reg_fb_ref=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; path=/; domain=.facebook.com s=Aa66PtcukmZymARh.BQcVkh; path=/; domain=.facebook.com; secure; httponly wd=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; path=/; domain=.facebook.com; httponly xs=60%3AEWmO0s7_6m0Gyg%3A0%3A1349605665; path=/; domain=.facebook.com; httponly :)
  (: strip out cookie keys and values :)
  
  
  (: Fake login button click :)
  
  
  (: Response is a redirect :)
  (: https://www.facebook.com/dialog/permissions.request?_path=permissions.request&app_id=127268677421110&redirect_uri=http%3A%2F%2Flocalhost%3A8098%2Ffbreturn&display=page&response_type=code&fbconnect=1&from_login=1&client_id=127268677421110 :)
  
  
  (: This in turn redirects because the app is already authorised :)
  (: final response URL http://localhost:8098/fbreturn?      code= AQBqY8IcTRslihhPX0s0niH33zomYndHaT0h83WHJpYXDB22RNyhdxc9yeqrVgjgJHRcK8iRPl2sKrLefIJMOTinyPkqw7WnAhvExAjuewDPGiErPiE_WXi-iHstteWIA1i20lDqSTEpxkS7OczFCl-nbztRyB6i9ec-r1_XEnwF45Gyf7dv4Jpu6z24MxzA2mw-7Plqm4LSqVLvI0YTbsiA    #_=_ :)
  
  let $requri := fn:concat("https://www.facebook.com/dialog/oauth?client_id=",$appid,"&amp;redirect_uri=http://localhost:8098/fbreturn&amp;state=wibble")
  (: https://www.facebook.com/dialog/oauth?client_id=127268677421110&redirect_uri=http://localhost:8098/fbreturn&state=wibble :)
  return ()
};

declare function oauth2:facebookPostsInArea($access_token,$lon,$lat,$dist) {
  let $url := fn:concat("https://graph.facebook.com/search?type=location&amp;center=",$lat,",",$lon,"&amp;distance=",$dist,"&amp;access_token=",$access_token)
  (: https://graph.facebook.com/search?type=location&center=52.475074,1.829833&distance=50 :)
  let $l := xdmp:log($url)
  return xdmp:http-get($url,<options xmlns='xdmp:http-get'><format xmlns='xdmp:document-get'>text</format></options>)[2]
};

declare function oauth2:facebookSearch($access_token,$q) {
  let $url := fn:concat("https://graph.facebook.com/search?q=",$q,"&amp;access_token=",$access_token)
  let $l := xdmp:log($url)
  return xdmp:http-get($url,<options xmlns='xdmp:http-get'><format xmlns='xdmp:document-get'>text</format></options>)[2]
};

declare function oauth2:facebookSearchPublicPosts($q as xs:string,$since as xs:long?,$limit as xs:int?) {
  let $url := fn:concat("https://graph.facebook.com/search?q=",fn:encode-for-uri($q),"&amp;type=post") (: &amp;since=",$since,"&amp;limit=",($limit,1000)[1]) :)
  let $l := xdmp:log($url)
  return xdmp:http-get($url,<options xmlns='xdmp:http-get'><format xmlns='xdmp:document-get'>text</format></options>)[2]
};

declare function oauth2:facebookSearchUserPosts($userid as xs:string,$since as xs:long?,$limit as xs:int?) {
  (: NB Method requires access_token authentication :)
  let $url := fn:concat("https://graph.facebook.com/",$userid,"/feed&amp;type=post") (: &amp;since=",$since,"&amp;limit=",($limit,1000)[1]) :)
  let $l := xdmp:log($url)
  return xdmp:http-get($url,<options xmlns='xdmp:http-get'><format xmlns='xdmp:document-get'>text</format></options>)[2]
};



declare function oauth2:doRequest($url) {
  let $cmd := fn:concat("xquery version '1.0-ml'; xdmp:http-get('", 
                          $url, 
                          "', <options xmlns='xdmp:http-get'><format xmlns='xdmp:document-get'>text</format></options>)")
    let $profile_response :=  xdmp:eval($cmd)
    return
        if($profile_response[1]/xdmphttp:code/text() eq "200") then
            let $json_response := $profile_response[2]
            (:
            let $map_response := xdmp:from-json($profile_response[2])
            let $provider_user_data :=
                <provider-data name="facebook">
                    <id>{map:get($map_response,"id")}</id>
                    <name>{map:get($map_response,"name")}</name>
                    <link>{map:get($map_response,"link")}</link>
                    <gender>{map:get($map_response,"gender")}</gender>
                    <picture>{fn:concat("http://graph.facebook.com/", map:get($map_response,"id"), "/picture" )}</picture>
                </provider-data>
            return
                $provider_user_data
                :)
            return $json_response
        else 
            ()
};

declare function oauth2:facebookGetUserProfile($access_token,$username) {
    let $profile_url := fn:concat("https://graph.facebook.com/",$username,"?access_token=", $access_token)
    
    return oauth2:doRequest($profile_url)
  
};

(:~
 : Given the user_data map, get the request token and call to Facebook to get profile information
 : populate the profile information in the map (see within for those values
 :) 
declare function oauth2:facebookUserProfileInfo($access_token)  {
  oauth2:facebookGetUserProfile($access_token,"me")
};


(:~
 : Given the user_data map, get the request token and call to Facebook to get profile information
 : populate the profile information in the map (see within for those values
 :) 
declare function oauth2:githubUserProfileInfo($access_token)  {
    let $profile_url := fn:concat("https://github.com/api/v2/xml/user/show?access_token=", $access_token)
    let $cmd := fn:concat("xquery version '1.0-ml'; xdmp:http-get('", 
                          $profile_url, 
                          "')")
    let $profile_response :=  xdmp:eval($cmd)
    return
        if($profile_response[1]/xdmphttp:code/text() eq "200") then
            let $xml_response := $profile_response[2]
            let $provider_user_data :=
                <provider-data name="github">
                    <id>{$xml_response/user/login/text()}</id>
                    <name>{$xml_response/user/name/text()}</name>
                    <link>{fn:concat("http://github.com/", $xml_response/user/login/text())}</link>
                    <picture>{fn:concat("http://www.gravatar.com/avatar/", $xml_response/user/gravatar-id/text())}</picture>
                </provider-data>
            return
                $provider_user_data
        else 
            ()
    
};

(:~
 : Parse the response text of an outh2 access token request into the token and 
 : expiration date
 : @param $responseText response text of the access token request
 : @return map containing access_token, expires
 :)
declare function oauth2:parseAccessToken($responseText) as item()+ {
   let $params := fn:tokenize($responseText, "&amp;")
   let $access_token := fn:tokenize($params[1], "=")[2]
   let $expires_seconds := if($params[2]) then fn:tokenize($params[2], "=")[2] else ()
   let $expires := if($params[2]) then fn:current-dateTime() + xs:dayTimeDuration(fn:concat("PT", $expires_seconds, "S")) else ()
   let $user_data := map:map()
   let $key := map:put($user_data, "access_token", $access_token)
   let $key := map:put($user_data, "expires", $expires)
   return $user_data
};


