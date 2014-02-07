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

module namespace te="http://marklogic.com/libs/temporal";

(: The Lords Temporal :)


declare variable $MONTHS
       := (<Jan>01</Jan>, <Feb>02</Feb>, <Mar>03</Mar>, <Apr>04</Apr>, <May>05</May>, <Jun>06</Jun>,
           <Jul>07</Jul>, <Aug>08</Aug>, <Sep>09</Sep>, <Oct>10</Oct>, <Nov>11</Nov>, <Dec>12</Dec>);

declare function te:date($x as xs:string) as xs:string {
let $created := fn:string($x)
           let $month   := fn:string($MONTHS[fn:local-name(.) = fn:substring($created, 5, 3)])
           let $year    := fn:substring($created, fn:string-length($created) - 3)
           let $day     := fn:replace($created, "... ... (\d+).*", "$1")
           let $date    := fn:replace($created, "... ... \d+ (........) (...)(..).*",
                                   fn:concat($year,"-",$month,"-",
                                          if (fn:string-length($day) < 2) then "0" else "",
                                          $day, "T$1$2:$3"))
           return $date
};

declare function te:short-dt($dt as xs:dateTime) as xs:string {
  fn:format-dateTime($dt,"[Y01]/[M01]/[D01] [H01]:[m01]:[s01] [z]")
};

declare function te:string-to-w3c($s as xs:string) as xs:dateTime {
  (: 2012-10-07T12:49:57+0000 :)
  (: TODO support timezones - I think Facebook returns Zulu anyway, but just in case we should support it :)
  
let $t := fn:tokenize($s,"T")
let $times := fn:substring($t[2],1,8)
let $time := xs:time($times)
let $date := xs:date($t[1])
(:
let $hours := fn:substring($t[2],9,13)

let $zuluTime := $time - xs:gHour($hours cast as xs:integer ):)

let $dateTime := xs:dateTime($date,$time)
return $dateTime
};